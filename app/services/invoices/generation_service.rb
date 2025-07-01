# frozen_string_literal: true

module Invoices
  # Service to generate invoices for vendors with uninvoiced transactions
  #
  # LOGIC FLOW:
  # 1. Find all vendors with uninvoiced transactions (VoucherTransaction.completed.where(invoice_id: nil))
  # 2. For each vendor:
  #    a. Calculate date range (from last invoice end_date or 14 days ago)
  #    b. Find uninvoiced transactions in that date range
  #    c. Create Invoice record with calculated totals
  #    d. Associate transactions with the new invoice
  #    e. Create audit event for the invoice
  #    f. Send notifications to vendor and admins
  #
  # MODELS USED:
  # - VoucherTransaction (finding uninvoiced transactions)
  # - Invoice (creating new invoices, finding latest for date range)
  # - User (finding administrators for notifications)
  #
  # MAILERS USED:
  # - VendorNotificationsMailer.invoice_generated (notifies vendor)
  # - AdminNotificationsMailer.invoice_ready_for_review (notifies all admins)
  #
  # CALLED BY:
  # - GenerateVendorInvoicesJob (app/jobs/generate_vendor_invoices_job.rb)
  #
  class GenerationService < BaseService
    def call
      vendor_ids = find_vendors_with_uninvoiced_transactions

      return success('No vendors found with uninvoiced transactions', { invoices_created: 0 }) if vendor_ids.empty?

      invoices_created = 0

      vendor_ids.each do |vendor_id|
        result = generate_invoice_for_vendor(vendor_id)
        invoices_created += 1 if result.success?
      end

      success("Generated #{invoices_created} invoices", { invoices_created: invoices_created })
    rescue StandardError => e
      log_error(e, 'Failed to generate vendor invoices')
      failure('Failed to generate vendor invoices')
    end

    private

    def find_vendors_with_uninvoiced_transactions
      VoucherTransaction
        .completed
        .where(invoice_id: nil)
        .select(:vendor_id)
        .distinct
        .pluck(:vendor_id)
    end

    def generate_invoice_for_vendor(vendor_id)
      date_range = calculate_date_range_for_vendor(vendor_id)
      transactions = find_uninvoiced_transactions(vendor_id, date_range)

      return success('No transactions found for vendor') if transactions.empty?

      ActiveRecord::Base.transaction do
        invoice = create_invoice(vendor_id, date_range, transactions)
        associate_transactions_with_invoice(transactions, invoice)
        create_invoice_event(invoice, transactions, date_range)
        send_notifications(invoice)

        success('Invoice generated successfully', { invoice: invoice })
      end
    rescue StandardError => e
      log_error(e, "Failed to generate invoice for vendor #{vendor_id}")
      failure("Failed to generate invoice for vendor #{vendor_id}")
    end

    def calculate_date_range_for_vendor(vendor_id)
      latest_invoice = Invoice.for_vendor(vendor_id).order(end_date: :desc).first
      start_date = latest_invoice ? latest_invoice.end_date : 14.days.ago.beginning_of_day
      end_date = Time.current.end_of_day

      { start_date: start_date, end_date: end_date }
    end

    def find_uninvoiced_transactions(vendor_id, date_range)
      VoucherTransaction
        .completed
        .where(invoice_id: nil)
        .where(vendor_id: vendor_id)
        .where(processed_at: date_range[:start_date]..date_range[:end_date])
    end

    def create_invoice(vendor_id, date_range, transactions)
      Invoice.create!(
        vendor_id: vendor_id,
        period_start: date_range[:start_date],
        period_end: date_range[:end_date],
        status: :pending,
        total_amount: transactions.sum(:amount),
        invoice_number: generate_invoice_number
      )
    end

    def associate_transactions_with_invoice(transactions, invoice)
      transactions.find_each do |transaction|
        transaction.update!(invoice_id: invoice.id)
      end
    end

    def create_invoice_event(invoice, transactions, date_range)
      invoice.events.create!(
        user: nil,
        action: 'generated',
        metadata: {
          transaction_count: transactions.count,
          total_amount: invoice.total_amount,
          period: {
            start: date_range[:start_date],
            end: date_range[:end_date]
          }
        }
      )
    end

    def send_notifications(invoice)
      send_vendor_notification(invoice)
      send_admin_notifications(invoice)
    end

    def send_vendor_notification(invoice)
      VendorNotificationsMailer.invoice_generated(invoice).deliver_later
    end

    def send_admin_notifications(invoice)
      User.where(type: 'Users::Administrator').find_each do |admin|
        AdminNotificationsMailer.invoice_ready_for_review(admin, invoice).deliver_later
      end
    end

    def generate_invoice_number
      date_part = Time.current.strftime('%Y%m')
      sequence = (Invoice.where('invoice_number LIKE ?', "INV-#{date_part}-%").count + 1)
                 .to_s
                 .rjust(4, '0')

      "INV-#{date_part}-#{sequence}"
    end
  end
end
