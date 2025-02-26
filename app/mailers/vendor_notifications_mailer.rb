class VendorNotificationsMailer < ApplicationMailer
  def invoice_generated(invoice)
    @invoice = invoice
    @vendor = invoice.vendor
    @transactions = invoice.voucher_transactions.includes(:voucher)

    attachments["invoice-#{@invoice.invoice_number}.pdf"] = generate_invoice_pdf

    mail(
      to: @vendor.email,
      subject: "New Invoice Generated - #{@invoice.invoice_number}"
    )
  end

  def payment_issued(invoice)
    @invoice = invoice
    @vendor = invoice.vendor

    mail(
      to: @vendor.email,
      subject: "Payment Issued for Invoice #{@invoice.invoice_number}"
    )
  end

  def w9_expiring_soon(vendor)
    @vendor = vendor
    @days_until_expiry = (vendor.w9_expiration_date - Date.current).to_i

    mail(
      to: @vendor.email,
      subject: "W9 Form Expiring Soon"
    )
  end

  def w9_expired(vendor)
    @vendor = vendor

    mail(
      to: @vendor.email,
      subject: "W9 Form Has Expired - Action Required"
    )
  end

  private

  def generate_invoice_pdf
    pdf = Prawn::Document.new do |pdf|
      # Header
      pdf.text "INVOICE", size: 24, style: :bold, align: :center
      pdf.move_down 20

      # Invoice Details
      pdf.text "Invoice Number: #{@invoice.invoice_number}"
      pdf.text "Date: #{@invoice.created_at.strftime('%B %d, %Y')}"
      pdf.move_down 20

      # Vendor Information
      pdf.text "Vendor:", style: :bold
      pdf.text @vendor.business_name
      pdf.text @vendor.business_tax_id
      pdf.move_down 20

      # Period
      pdf.text "Period:", style: :bold
      pdf.text "#{@invoice.period_start.strftime('%B %d, %Y')} - #{@invoice.period_end.strftime('%B %d, %Y')}"
      pdf.move_down 20

      # Transactions Table
      items = [ [ "Date", "Voucher", "Amount" ] ]
      @transactions.each do |transaction|
        items << [
          transaction.processed_at.strftime("%Y-%m-%d"),
          transaction.voucher.code,
          number_to_currency(transaction.amount)
        ]
      end

      pdf.table(items, header: true) do |table|
        table.row(0).style(background_color: "CCCCCC")
        table.cells.padding = 12
        table.column_widths = [ 150, 200, 150 ]
      end

      pdf.move_down 20

      # Total
      pdf.text "Total Amount: #{number_to_currency(@invoice.total_amount)}",
        size: 14,
        style: :bold,
        align: :right

      # Footer
      pdf.move_down 40
      pdf.text "Please allow up to 30 days for payment processing.", size: 10
      pdf.text "Contact support@example.com for any questions.", size: 10
    end

    pdf.render
  end
end
