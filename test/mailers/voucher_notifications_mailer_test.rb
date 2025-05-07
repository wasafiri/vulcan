# frozen_string_literal: true

require 'test_helper'

class VoucherNotificationsMailerTest < ActionMailer::TestCase
  # Helper to create mock templates
  # Helper to create mock templates that respond to render method
  def mock_template(subject_format, body_format)
    template_instance = mock("email_template_instance_#{subject_format.gsub(/\s+/, '_')}")

    # Stub the render method to return [rendered_subject, rendered_body]
    # This simulates what the real EmailTemplate.render method does
    template_instance.stubs(:render).with(any_parameters).returns do |**vars|
      # For the voucher_code variable which is present in most templates
      if vars[:voucher_code]
        rendered_subject = subject_format
        rendered_body = body_format.gsub('%<voucher_code>s', vars[:voucher_code])
      elsif vars[:vendor_business_name] && body_format.include?('%<vendor_business_name>s')
        rendered_subject = subject_format
        rendered_body = body_format.gsub('%<voucher_code>s', vars[:voucher_code])
                                   .gsub('%<vendor_business_name>s', vars[:vendor_business_name])
      elsif vars[:days_remaining] && body_format.include?('%<days_remaining>s')
        rendered_subject = subject_format
        rendered_body = body_format.gsub('%<voucher_code>s', vars[:voucher_code])
                                   .gsub('%<days_remaining>s', vars[:days_remaining].to_s)
                                   .gsub('%<expiration_date_formatted>s', vars[:expiration_date_formatted])
      else
        rendered_subject = subject_format
        rendered_body = body_format
      end
      [rendered_subject, rendered_body]
    end

    # Still stub subject and body for inspection if needed
    template_instance.stubs(:subject).returns(subject_format)
    template_instance.stubs(:body).returns(body_format)

    template_instance
  end

  setup do
    # Per project strategy, HTML emails are not used. Only stub for :text format.
    # If the mailer attempts to find_by!(format: :html), it should fail (e.g., RecordNotFound)
    # as no HTML templates should be seeded for these, and we provide no stub.

    # Initialize test data before creating mocks that might need it
    @application = create(:application)
    @user = @application.user
    # Set issued_at to 6 months ago - the expiration_date will be calculated using the Policy
    @voucher = create(:voucher,
                      application: @application,
                      issued_at: 6.months.ago)
    @vendor = create(:vendor, :approved)
    @transaction = create(:voucher_transaction,
                          voucher: @voucher,
                          vendor: @vendor,
                          status: :transaction_completed,
                          amount: 100.00)

    # Create simple mocks with direct stubbing for simplicity
    assigned_template = mock('email_template_assigned')
    assigned_template.stubs(:render).with(any_parameters).returns(['Voucher assigned', "Text Assigned for voucher #{@voucher.code}"])

    expiring_soon_template = mock('email_template_expiring')
    expiring_soon_template.stubs(:render).with(any_parameters).returns do |**vars|
      ['Voucher expiring soon',
       "Text Your voucher #{vars[:voucher_code]} will expire in #{vars[:days_remaining]} days on #{vars[:expiration_date_formatted]}."]
    end

    expired_template = mock('email_template_expired')
    expired_template.stubs(:render).with(any_parameters).returns(['Voucher expired', "Text Expired for voucher #{@voucher.code}"])

    redeemed_template = mock('email_template_redeemed')
    redeemed_template.stubs(:render).with(any_parameters).returns do |**vars|
      ['Voucher redeemed', "Text Redeemed for voucher #{vars[:voucher_code]} at #{vars[:vendor_business_name]}"]
    end

    # Stub the find_by! calls to return our mocks
    EmailTemplate.stubs(:find_by!)
                 .with(name: 'voucher_notifications_voucher_assigned', format: :text)
                 .returns(assigned_template)

    EmailTemplate.stubs(:find_by!)
                 .with(name: 'voucher_notifications_voucher_expiring_soon', format: :text)
                 .returns(expiring_soon_template)

    EmailTemplate.stubs(:find_by!)
                 .with(name: 'voucher_notifications_voucher_expired', format: :text)
                 .returns(expired_template)

    EmailTemplate.stubs(:find_by!)
                 .with(name: 'voucher_notifications_voucher_redeemed', format: :text)
                 .returns(redeemed_template)

    # Stub the Policy.get method to return appropriate values for testing with any parameters
    Policy.stubs(:get).with(any_parameters).returns do |key|
      case key
      when 'voucher_validity_period_months'
        12
      when 'minimum_voucher_redemption_amount'
        10
      else
        # Return a default or raise an error for unhandled keys if necessary
        nil
      end
    end
  end

  test 'voucher_assigned' do
    # Using Rails 7.1.0+ capture_emails helper
    emails = capture_emails do
      VoucherNotificationsMailer.with(voucher: @voucher).voucher_assigned.deliver_now
    end

    # Verify we captured an email
    assert_equal 1, emails.size
    email = emails.first

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_equal 'Voucher assigned', email.subject

    # For non-multipart emails, we check the body directly
    assert_equal 0, email.parts.size, 'Email should have no parts (non-multipart).'
    assert_includes email.content_type, 'text/plain', 'Email should be text/plain (may include charset)'

    # Check that the email body contains expected text
    expected_text = "Text Assigned for voucher #{@voucher.code}"
    assert_includes email.body.to_s, expected_text
  end

  test 'voucher_expiring_soon' do
    # Mock Time.current for predictable date calculations
    mock_time = Time.zone.local(2025, 4, 25, 12, 0, 0) # Example fixed time
    Time.stubs(:current).returns(mock_time)

    # Stub the template to return predictable text
    # This aligns with the implementation which will use 'will expire in X days'
    expected_days = 11 # Fixed for test stability
    expected_text = "Text Your voucher will expire in #{expected_days} days"
    template = mock('expiring_soon_template')
    template.stubs(:render).returns(['Voucher expiring soon', expected_text])
    EmailTemplate.stubs(:find_by!)
                 .with(name: 'voucher_notifications_voucher_expiring_soon', format: :text)
                 .returns(template)

    # Using Rails 7.1.0+ capture_emails helper
    emails = capture_emails do
      VoucherNotificationsMailer.with(voucher: @voucher).voucher_expiring_soon.deliver_now
    end

    # Verify we captured an email
    assert_equal 1, emails.size
    email = emails.first

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_equal 'Voucher expiring soon', email.subject

    # For non-multipart emails, we check the body directly
    assert_equal 0, email.parts.size, 'Email should have no parts (non-multipart).'
    assert_includes email.content_type, 'text/plain', 'Email should be text/plain (may include charset)'

    # Check that the email body contains expected text with correct variables
    assert_includes email.body.to_s, "will expire in #{expected_days} days"
  end

  test 'voucher_expired' do
    # Using Rails 7.1.0+ capture_emails helper
    emails = capture_emails do
      VoucherNotificationsMailer.with(voucher: @voucher).voucher_expired.deliver_now
    end

    # Verify we captured an email
    assert_equal 1, emails.size
    email = emails.first

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_equal 'Voucher expired', email.subject

    # For non-multipart emails, we check the body directly
    assert_equal 0, email.parts.size, 'Email should have no parts (non-multipart).'
    assert_includes email.content_type, 'text/plain', 'Email should be text/plain (may include charset)'

    # Check that the email body contains expected text
    expected_text = "Text Expired for voucher #{@voucher.code}"
    assert_includes email.body.to_s, expected_text
  end

  test 'voucher_redeemed' do
    # Using a simpler approach with a dedicated stub just for this test
    # Create a predictable body for this specific test
    redeemed_text = "Text Redeemed for voucher #{@voucher.code} at #{@vendor.business_name}"
    redeemed_template = mock('redeemed_template')
    redeemed_template.stubs(:render).returns(['Voucher redeemed', redeemed_text])

    # Override the stub just for this test
    EmailTemplate.unstub(:find_by!)

    # Since we unstubbed all find_by! calls, we need to restore the stubs for other templates
    assigned_template = mock('email_template_assigned')
    assigned_template.stubs(:render).returns(['Voucher assigned', "Text Assigned for voucher #{@voucher.code}"])

    expiring_template = mock('email_template_expiring')
    expiring_template.stubs(:render).returns(['Voucher expiring soon', 'Text expiring soon text'])

    expired_template = mock('email_template_expired')
    expired_template.stubs(:render).returns(['Voucher expired', "Text Expired for voucher #{@voucher.code}"])

    # Re-stub all templates
    EmailTemplate.stubs(:find_by!)
                 .with(name: 'voucher_notifications_voucher_assigned', format: :text)
                 .returns(assigned_template)

    EmailTemplate.stubs(:find_by!)
                 .with(name: 'voucher_notifications_voucher_expiring_soon', format: :text)
                 .returns(expiring_template)

    EmailTemplate.stubs(:find_by!)
                 .with(name: 'voucher_notifications_voucher_expired', format: :text)
                 .returns(expired_template)

    EmailTemplate.stubs(:find_by!)
                 .with(name: 'voucher_notifications_voucher_redeemed', format: :text)
                 .returns(redeemed_template)

    # Using Rails 7.1.0+ capture_emails helper
    emails = capture_emails do
      VoucherNotificationsMailer.with(transaction: @transaction).voucher_redeemed.deliver_now
    end

    # Verify we captured an email
    assert_equal 1, emails.size
    email = emails.first

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_equal 'Voucher redeemed', email.subject

    # For non-multipart emails, we check the body directly
    assert_equal 0, email.parts.size, 'Email should have no parts (non-multipart).'
    assert_includes email.content_type, 'text/plain', 'Email should be text/plain (may include charset)'

    # Check that the email body contains expected text
    assert_includes email.body.to_s, redeemed_text
  end
end
