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
      scope = case params[:filter]
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

      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where(vendor_id: params[:vendor_id]) if params[:vendor_id].present?

      if params[:date_range].present?
        case params[:date_range]
        when 'today'
          scope = scope.where(created_at: Time.current.beginning_of_day..Time.current.end_of_day)
        when 'week'
          scope = scope.where(created_at: 1.week.ago.beginning_of_day..Time.current.end_of_day)
        when 'month'
          scope = scope.where(created_at: 1.month.ago.beginning_of_day..Time.current.end_of_day)
        when 'custom'
          if params[:start_date].present? && params[:end_date].present?
            start_date = Date.parse(params[:start_date])
            end_date   = Date.parse(params[:end_date])
            scope = scope.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
          end
        end
      end

      scope
    end

    def send_vouchers_csv(vouchers)
      send_data generate_csv(vouchers),
                filename: "vouchers-#{Time.current.strftime('%Y%m%d')}.csv",
                type: 'text/csv'
    end

    def generate_csv(vouchers)
      require 'csv'
      CSV.generate(headers: true) do |csv|
        csv << csv_headers
        vouchers.find_each do |voucher|
          csv << voucher_csv_row(voucher)
        end
      end
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
