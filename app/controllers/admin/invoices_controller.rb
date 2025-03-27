# frozen_string_literal: true

module Admin
  class InvoicesController < Admin::BaseController
    include Pagy::Backend

    before_action :set_invoice, only: %i[how update mark_check_issued mark_check_cashed]
    before_action :require_admin!

    def index
      scope = Invoice.includes(:vendor, :voucher_transactions)
                     .order(created_at: :desc)

      scope = apply_filters(scope)
      @pagy, @invoices = pagy(scope, items: 25)

      # Get vendor totals for current period (uninvoiced transactions)
      @vendor_totals = Vendor.active
                             .joins(:voucher_transactions)
                             .where(voucher_transactions: { invoice_id: nil,
                                                            status: VoucherTransaction.statuses[:transaction_completed] })
                             .group('users.id, users.business_name')
                             .select('users.id, users.business_name, SUM(voucher_transactions.amount) as total_amount, COUNT(DISTINCT voucher_transactions.id) as transaction_count')
                             .order('total_amount DESC')

      respond_to do |format|
        format.html
        format.csv do
          send_data generate_csv(@invoices), filename: "invoices-#{Time.current.strftime('%Y%m%d')}.csv",
                                             type: 'text/csv'
        end
      end
    end

    def show
      @transactions = @invoice.voucher_transactions
                              .includes(:voucher)
                              .order(processed_at: :desc)
    end

    def update
      if @invoice.update(invoice_params)
        notice = if @invoice.saved_change_to_status? && @invoice.invoice_approved?
                   'Invoice approved successfully'
                 elsif @invoice.saved_change_to_status? && @invoice.invoice_paid?
                   'Payment details recorded successfully'
                 else
                   'Invoice updated successfully'
                 end

        log_event!('Updated invoice details', {
                     status_changed: @invoice.saved_change_to_status?,
                     new_status: @invoice.status,
                     gad_reference: @invoice.gad_invoice_reference
                   })

        redirect_to [:admin, @invoice], notice: notice
      else
        render :show, status: :unprocessable_entity
      end
    end

    def approve
      if @invoice.pending?
        @invoice.update!(status: :approved)
        log_event!('Approved invoice')
        redirect_to [:admin, @invoice], notice: 'Invoice approved successfully'
      else
        redirect_to [:admin, @invoice], alert: 'Invoice must be pending to approve'
      end
    end

    private

    def set_invoice
      @invoice = Invoice.find(params[:id])
    end

    def invoice_params
      params.require(:invoice).permit(
        :status,
        :payment_notes,
        :gad_invoice_reference
      )
    end

    def apply_filters(scope)
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
            end_date = Date.parse(params[:end_date])
            scope = scope.where(created_at: start_date.beginning_of_day..end_date.end_of_day)
          end
        end
      end

      if params[:payment_status].present?
        case params[:payment_status]
        when 'pending_check'
          scope = scope.where(status: :approved, check_number: nil)
        when 'check_issued'
          scope = scope.where.not(check_number: nil).where(check_cashed_at: nil)
        when 'check_cashed'
          scope = scope.where.not(check_cashed_at: nil)
        end
      end

      scope
    end

    def generate_csv(invoices)
      require 'csv'

      CSV.generate(headers: true) do |csv|
        csv << [
          'Invoice Number',
          'Vendor',
          'Total Amount',
          'Status',
          'Created At',
          'Check Number',
          'Check Issued At',
          'Check Cashed At',
          'GAD Reference'
        ]

        invoices.find_each do |invoice|
          csv << [
            invoice.invoice_number,
            invoice.vendor.business_name,
            invoice.total_amount,
            invoice.status,
            invoice.created_at.strftime('%Y-%m-%d %H:%M:%S'),
            invoice.check_number,
            invoice.check_issued_at&.strftime('%Y-%m-%d'),
            invoice.check_cashed_at&.strftime('%Y-%m-%d'),
            invoice.gad_invoice_reference
          ]
        end
      end
    end

    def log_event!(action, metadata = {})
      @invoice.events.create!(
        user: current_user,
        action: action,
        metadata: metadata.merge(
          changes: @invoice.saved_changes,
          admin_id: current_user.id
        )
      )
    end
  end
end
