# frozen_string_literal: true

module Admin
  class PrintQueueController < Admin::BaseController
    before_action :require_admin

    def index
      @pending_letters = PrintQueueItem.pending.includes(:constituent, :application, :admin).order(created_at: :desc)
      @printed_letters = PrintQueueItem.printed.includes(:constituent, :application,
                                                         :admin).order(printed_at: :desc).limit(50)
    end

    def show
      @letter = PrintQueueItem.find(params[:id])

      respond_to do |format|
        format.html
        format.pdf do
          if @letter.pdf_letter.attached?
            send_data @letter.pdf_letter.download,
                      filename: "#{@letter.letter_type}_#{@letter.constituent.id}.pdf",
                      type: 'application/pdf',
                      disposition: 'inline'
          else
            redirect_to admin_print_queue_index_path, alert: 'PDF not available for this letter'
          end
        end
      end
    end

    def mark_as_printed
      letter = PrintQueueItem.find(params[:id])
      letter.update(status: :printed, printed_at: Time.current, admin: current_user)
      redirect_to admin_print_queue_index_path, notice: 'Letter marked as printed'
    end

    def mark_batch_as_printed
      @letters = PrintQueueItem.where(id: params[:letter_ids])

      if @letters.empty?
        redirect_to admin_print_queue_index_path, alert: 'No letters selected'
        return
      end

      # Update all selected letters to printed status
      @letters.update_all(
        status: PrintQueueItem.statuses[:printed],
        printed_at: Time.current,
        admin_id: current_user.id
      )

      redirect_to admin_print_queue_index_path,
                  notice: "#{@letters.count} #{'letter'.pluralize(@letters.count)} marked as printed"
    end

    def download_batch
      @letters = PrintQueueItem.where(id: params[:letter_ids])

      return redirect_empty_letters if @letters.empty?
      return send_single_letter(@letters.first) if @letters.one?

      send_multiple_letters(@letters)
    end

    private

    def require_admin
      return if current_user&.admin?

      redirect_to root_path, alert: 'You do not have permission to access this page'
    end

    def redirect_empty_letters
      redirect_to admin_print_queue_index_path, alert: 'No letters selected for download'
    end

    def send_single_letter(letter)
      filename = letter_filename(letter)
      send_data letter.pdf_letter.download,
                filename: filename,
                type: 'application/pdf',
                disposition: 'attachment',
                stream: false
    end

    def send_multiple_letters(letters)
      zipfile_name = build_zipfile_name
      temp_file = create_temp_file(zipfile_name)

      begin
        Zip::File.open(temp_file.path, Zip::File::CREATE) do |zipfile|
          populate_zip_file(zipfile, letters)
        end

        send_zip_file(temp_file, zipfile_name)
      rescue StandardError => e
        handle_zip_error(e)
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    def build_zipfile_name
      "letters_batch_#{Date.today.strftime('%Y%m%d')}.zip"
    end

    def create_temp_file(name)
      Tempfile.new(name)
    end

    def populate_zip_file(zipfile, letters)
      letters.each do |letter_item|
        next unless letter_item.pdf_letter.attached?

        zipfile.get_output_stream(letter_filename(letter_item)) do |file_stream|
          file_stream.write letter_item.pdf_letter.download
        end
      end
    end

    def send_zip_file(temp_file, zipfile_name)
      send_file temp_file.path,
                filename: zipfile_name,
                type: 'application/zip',
                disposition: 'attachment',
                stream: false
    end

    def handle_zip_error(exception)
      Rails.logger.error("PDF batch download error: #{exception.message}")
      redirect_to admin_print_queue_index_path, alert: 'An error occurred while preparing the download'
    end

    def letter_filename(letter)
      "#{letter.letter_type}_#{letter.constituent.id}.pdf"
    end
  end
end
