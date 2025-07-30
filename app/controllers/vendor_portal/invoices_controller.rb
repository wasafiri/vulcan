# frozen_string_literal: true

module VendorPortal
  class InvoicesController < VendorPortal::BaseController
    before_action :set_invoice, only: [:show]

    # GET /vendor/invoices
    def index
      @invoices = current_user.invoices.order(created_at: :desc)
      # Basic pagination, can be enhanced with a gem like Kaminari or Pagy
      # @invoices = @invoices.page(params[:page]).per(10)
    end

    # GET /vendor/invoices/:id
    def show
      # @invoice is set by set_invoice
    end

    private

    def set_invoice
      @invoice = current_user.invoices.find_by(id: params[:id])
      redirect_to vendor_portal_invoices_path, alert: 'Invoice not found.' unless @invoice
    end
  end
end
