class GenerateVendorInvoicesJob < ApplicationJob
  queue_as :default

  def perform
    # Find vendors with uninvoiced transactions
    vendor_ids = VoucherTransaction
      .completed
      .where(invoice_id: nil)
      .select(:vendor_id)
      .distinct
      .pluck(:vendor_id)

    vendor_ids.each do |vendor_id|
      # Calculate date range for this invoice
      latest_invoice = Invoice.for_vendor(vendor_id).order(end_date: :desc).first
      start_date = latest_invoice ? latest_invoice.end_date : 14.days.ago.beginning_of_day
      end_date = Time.current.end_of_day

      # Get all completed, uninvoiced transactions for this vendor in date range
      transactions = VoucherTransaction
        .completed
        .where(invoice_id: nil)
        .where(vendor_id: vendor_id)
        .where(processed_at: start_date..end_date)

      next if transactions.empty?

      # Create invoice
      ActiveRecord::Base.transaction do
        invoice = Invoice.create!(
          vendor_id: vendor_id,
          period_start: start_date,
          period_end: end_date,
          status: :pending,
          total_amount: transactions.sum(:amount),
          invoice_number: generate_invoice_number
        )

        # Associate transactions with this invoice
        transactions.update_all(invoice_id: invoice.id)

        # Create event
        invoice.events.create!(
          user: nil,
          action: "generated",
          metadata: {
            transaction_count: transactions.count,
            total_amount: invoice.total_amount,
            period: {
              start: start_date,
              end: end_date
            }
          }
        )

        # Notify vendor
        VendorNotificationsMailer.invoice_generated(invoice).deliver_later

        # Notify admins
        Admin.find_each do |admin|
          AdminNotificationsMailer.invoice_ready_for_review(
            admin,
            invoice
          ).deliver_later
        end
      end
    end
  end

  private

  def generate_invoice_number
    date_part = Time.current.strftime("%Y%m")
    sequence = (Invoice.where("invoice_number LIKE ?", "INV-#{date_part}-%").count + 1)
      .to_s
      .rjust(4, "0")

    "INV-#{date_part}-#{sequence}"
  end
end
