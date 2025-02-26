require "test_helper"

class VendorNotificationsMailerTest < ActionMailer::TestCase
  setup do
    @vendor = vendors(:one)
    @invoice = invoices(:one)
    @invoice.vendor = @vendor
    @transactions = @invoice.voucher_transactions
  end

  test "invoice_generated" do
    email = VendorNotificationsMailer.invoice_generated(@invoice)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "info@mdmat.org" ], email.from
    assert_equal [ @vendor.email ], email.to
    assert_match "Invoice Generated", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_includes html_part.body.to_s, "Invoice"
    assert_includes html_part.body.to_s, @invoice.invoice_number

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_includes text_part.body.to_s, "Invoice"
    assert_includes text_part.body.to_s, @invoice.invoice_number

    # Check for PDF attachment
    assert_equal 1, email.attachments.size
    attachment = email.attachments.first
    assert_equal "invoice-#{@invoice.invoice_number}.pdf", attachment.filename
    assert_equal "application/pdf", attachment.content_type
  end

  test "payment_issued" do
    email = VendorNotificationsMailer.payment_issued(@invoice)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "info@mdmat.org" ], email.from
    assert_equal [ @vendor.email ], email.to
    assert_match "Payment Issued", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_includes html_part.body.to_s, "Payment"
    assert_includes html_part.body.to_s, @invoice.invoice_number

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_includes text_part.body.to_s, "Payment"
    assert_includes text_part.body.to_s, @invoice.invoice_number
  end

  test "w9_expiring_soon" do
    @vendor.w9_expiration_date = 30.days.from_now

    email = VendorNotificationsMailer.w9_expiring_soon(@vendor)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "info@mdmat.org" ], email.from
    assert_equal [ @vendor.email ], email.to
    assert_match "W9 Form Expiring Soon", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_includes html_part.body.to_s, "expiring"
    assert_includes html_part.body.to_s, "30 days"

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_includes text_part.body.to_s, "expiring"
    assert_includes text_part.body.to_s, "30 days"
  end

  test "w9_expired" do
    email = VendorNotificationsMailer.w9_expired(@vendor)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "info@mdmat.org" ], email.from
    assert_equal [ @vendor.email ], email.to
    assert_match "W9 Form Has Expired", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_includes html_part.body.to_s, "expired"
    assert_includes html_part.body.to_s, "Action Required"

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_includes text_part.body.to_s, "expired"
    assert_includes text_part.body.to_s, "Action Required"
  end
end
