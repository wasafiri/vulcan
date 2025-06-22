# frozen_string_literal: true

module Admin
  class VouchersController < Admin::BaseController
    include Pagy::Backend

    before_action :set_voucher, only: %i[show update cancel]
    before_action :require_admin!

    def index
      load_status_counts

      scope = Voucher.includes(:vendor).order(created_at: :desc)
      scope = apply_filters(scope)
      @pagy, @vouchers = pagy(scope, items: 25)

      respond_to do |format|
        format.html
        format.csv { send_vouchers_csv(@vouchers) }
      end
    end

    def show
      @transactions = @voucher.transactions.includes(:vendor)
                              .order(processed_at: :desc)

      @audit_logs = Event.where('metadata @> ?', { voucher_id: @voucher.id }.to_json)
                         .or(Event.where('metadata @> ?', { voucher_code: @voucher.code }.to_json))
                         .includes(:user)
                         .order(created_at: :desc)
    end

    def update
      if @voucher.update(voucher_params)
        log_event!('Updated voucher details')
        redirect_to [:admin, @voucher], notice: 'Voucher updated successfully'
      else
        render :show, status: :unprocessable_entity
      end
    end

    def cancel
      if @voucher.can_cancel?
        @voucher.update!(status: :cancelled)
        log_event!('Cancelled voucher')
        redirect_to [:admin, @voucher], notice: 'Voucher cancelled successfully'
      else
        redirect_to [:admin, @voucher], alert: 'Cannot cancel this voucher'
      end
    end

    private

    def set_voucher
      @voucher = Voucher.find_by(code: params[:code] || params[:id]) || Voucher.find_by(id: params[:id])
    end

    def voucher_params
      params.require(:voucher).permit(:status, :expiration_date, :notes)
    end

    def load_status_counts
      @active_vouchers_count   = Voucher.where(status: :active).count
      @expiring_soon_count     = Voucher.expiring_soon.count
      @redeemed_vouchers_count = Voucher.where(status: :redeemed).count
      @unassigned_vouchers_count = Voucher.where(status: :active, vendor_id: nil).count
    end

    def apply_filters(scope)
      scope = apply_status_filter(scope)
      scope = apply_additional_filters(scope)
      scope = apply_date_range_filter(scope)
      scope
    end

    def apply_status_filter(scope)
      case params[:filter]
      when 'active'
        scope.where(status: :active)
      when 'expiring_soon'
        scope.expiring_soon
      when 'redeemed'
        scope.where(status: :redeemed)
      when 'unassigned'
        scope.where(status: :active, vendor_id: nil)
      else
        params[:filter].present? ? scope : scope.where(status: :active)
      end
    end

    def apply_additional_filters(scope)
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where(vendor_id: params[:vendor_id]) if params[:vendor_id].present?
      scope
    end

    def apply_date_range_filter(scope)
      return scope unless params[:date_range].present?

      case params[:date_range]
      when 'today'
        apply_today_filter(scope)
      when 'week'
        apply_week_filter(scope)
      when 'month'
        apply_month_filter(scope)
      when 'custom'
        apply_custom_date_filter(scope)
      else
        scope
      end
    end

    def apply_today_filter(scope)
      scope.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
    end

    def apply_week_filter(scope)
      scope.where(created_at: 1.week.ago.beginning_of_day..Time.current.end_of_day)
    end

    def apply_month_filter(scope)
      scope.where(created_at: 1.month.ago.beginning_of_day..Time.current.end_of_day)
    end

    def apply_custom_date_filter(scope)
      return scope unless params[:start_date].present? && params[:end_date].present?

      start_date = Date.parse(params[:start_date])
      end_date = Date.parse(params[:end_date])
      scope.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
    rescue Date::Error
      scope # Return unmodified scope if date parsing fails
    end

    def send_vouchers_csv(vouchers)
      send_data generate_csv(vouchers),
                filename: "vouchers-#{Time.current.strftime('%Y%m%d')}.csv",
                type: 'text/csv'
    end

    def generate_csv(vouchers)
      require 'smarter_csv'

      vouchers_data = vouchers.map do |voucher|
        {
          'Code' => voucher.code,
          'Status' => voucher.status,
          'Initial Value' => voucher.initial_value,
          'Remaining Value' => voucher.remaining_value,
          'Vendor' => voucher.vendor&.business_name,
          'Created At' => voucher.created_at.strftime('%Y-%m-%d %H:%M:%S'),
          'Expiration Date' => voucher.expiration_date&.strftime('%Y-%m-%d'),
          'Last Transaction' => voucher.transactions.last&.processed_at&.strftime('%Y-%m-%d %H:%M:%S')
        }
      end

      # Return empty string if no data to prevent errors
      return '' if vouchers_data.empty?

      temp_file = nil
      csv_content = nil

      begin
        # Create a temporary file
        temp_file = Tempfile.new(['vouchers', '.csv'])

        # Use SmarterCSV::Writer with the temp file path
        # Pass the whole data array; smarter_csv handles headers automatically
        writer = SmarterCSV::Writer.new(temp_file.path)
        writer << vouchers_data
        writer.finalize # This saves and closes the file stream managed by smarter_csv

        # Rewind and read the content from the temp file
        temp_file.rewind
        csv_content = temp_file.read
      ensure
        # Ensure the temp file is closed and deleted
        temp_file&.close
        temp_file&.unlink # Deletes the file from the filesystem
      end

      csv_content
    end

    def csv_headers
      ['Code', 'Status', 'Initial Value', 'Remaining Value', 'Vendor', 'Created At', 'Expiration Date',
       'Last Transaction']
    end

    def voucher_csv_row(voucher)
      [
        voucher.code,
        voucher.status,
        voucher.initial_value,
        voucher.remaining_value,
        voucher.vendor&.business_name,
        voucher.created_at.strftime('%Y-%m-%d %H:%M:%S'),
        voucher.expiration_date&.strftime('%Y-%m-%d'),
        voucher.transactions.last&.processed_at&.strftime('%Y-%m-%d %H:%M:%S')
      ]
    end

    def log_event!(action)
      Event.create!(
        user: current_user,
        action: action,
        metadata: {
          voucher_id: @voucher.id,
          voucher_code: @voucher.code,
          application_id: @voucher.application_id,
          changes: @voucher.saved_changes,
          admin_id: current_user.id,
          timestamp: Time.current.iso8601
        }
      )
    end
  end
end
