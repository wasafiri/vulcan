def download_batch
  @letters = PrintQueueItem.where(id: params[:letter_ids])

  # If no letters selected or found, redirect with an error
  if @letters.empty?
    redirect_to admin_print_queue_index_path, alert: 'No letters selected for download'
    return
  end

  # For a single letter, just send the PDF directly
  if @letters.count == 1
    letter = @letters.first
    filename = "#{letter.letter_type}_#{letter.constituent.id}.pdf"
    return send_data letter.pdf_letter.download,
                    filename: filename,
                    type: 'application/pdf',
                    disposition: 'attachment',
                    stream: false
  end

  # Create a zip file for multiple letters
  zipfile_name = "letters_batch_#{Date.today.strftime('%Y%m%d')}.zip"
  temp_file = Tempfile.new(zipfile_name)

  begin
    # Create a zip file using RubyZip
    Zip::File.open(temp_file.path, Zip::File::CREATE) do |zipfile|
      @letters.each do |letter_item|
        next unless letter_item.pdf_letter.attached?

        filename = "#{letter_item.letter_type}_#{letter_item.constituent.id}.pdf"
        # Add PDF content directly to the zip file
        zipfile.get_output_stream(filename) do |file_stream|
          file_stream.write letter_item.pdf_letter.download
        end
      end
    end

    # Send the generated zip file to the client
    send_file temp_file.path,
              filename: zipfile_name,
              type: 'application/zip',
              disposition: 'attachment',
              stream: false
  rescue StandardError => e
    Rails.logger.error("PDF batch download error: #{e.message}")
    redirect_to admin_print_queue_index_path, alert: 'An error occurred while preparing the download'
  ensure
    # Always close and unlink the temp file
    temp_file.close
    temp_file.unlink
  end
end
