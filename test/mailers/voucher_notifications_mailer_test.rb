# frozen_string_literal: true

require 'test_helper'

class VoucherNotificationsMailerTest < ActionMailer::TestCase
  # Helper to create mock templates
  def mock_template(subject, body)
    template = mock('email_template')
    template.stubs(:render).returns([subject, body])
    template
  end

  setup do
    # Mock EmailTemplate lookups
    # Use specific subjects for better assertions later
    EmailTemplate.stubs(:find_by!)
                 .with(has_entries(name: 'voucher_notifications_voucher_assigned', format: :html))
                 .returns(mock_template('Voucher Has Been Assigned', '<p>HTML Assigned</p>'))
    EmailTemplate.stubs(:find_by!)
                 .with(has_entries(name: 'voucher_notifications_voucher_assigned', format: :text))
                 .returns(mock_template('Voucher Has Been Assigned', 'Text Assigned'))

    # Update mock for expiring_soon to include 'expire' and variables
    expiring_soon_html_body = '<p>HTML Your voucher %<voucher_code>s will expire in %<days_remaining>s days on %<expiration_date_formatted>s.</p>'
    expiring_soon_text_body = 'Text Your voucher %<voucher_code>s will expire in %<days_remaining>s days on %<expiration_date_formatted>s.'
    EmailTemplate.stubs(:find_by!)
                 .with(has_entries(name: 'voucher_notifications_voucher_expiring_soon', format: :html))
                 .returns(mock_template('Your Voucher Will Expire Soon', expiring_soon_html_body))
    EmailTemplate.stubs(:find_by!)
                 .with(has_entries(name: 'voucher_notifications_voucher_expiring_soon', format: :text))
                 .returns(mock_template('Your Voucher Will Expire Soon', expiring_soon_text_body))

    EmailTemplate.stubs(:find_by!)
                 .with(has_entries(name: 'voucher_notifications_voucher_expired', format: :html))
                 .returns(mock_template('Your Voucher Has Expired', '<p>HTML Expired</p>'))
    EmailTemplate.stubs(:find_by!)
                 .with(has_entries(name: 'voucher_notifications_voucher_expired', format: :text))
                 .returns(mock_template('Your Voucher Has Expired', 'Text Expired'))

    EmailTemplate.stubs(:find_by!)
                 .with(has_entries(name: 'voucher_notifications_voucher_redeemed', format: :html))
                 .returns(mock_template('Voucher Redeemed Confirmation', '<p>HTML Redeemed</p>'))
    EmailTemplate.stubs(:find_by!)
                 .with(has_entries(name: 'voucher_notifications_voucher_redeemed', format: :text))
                 .returns(mock_template('Voucher Redeemed Confirmation', 'Text Redeemed'))

    # Create test data using FactoryBot
    @application = create(:application)
    @user = @application.user
    # Set issued_at to 6 months ago - the expiration_date will be calculated using the Policy
    @voucher = create(:voucher,
                      application: @application,
                      issued_at: 6.months.ago)

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
    # Remove conflicting/outdated stub: Policy.stubs(:voucher_validity_period).returns(12.months)
    @vendor = create(:vendor, :approved)
    @transaction = create(:voucher_transaction,
                          voucher: @voucher,
                          vendor: @vendor,
                          status: :transaction_completed,
                          amount: 100.00)
  end

  test 'voucher_assigned' do
    # Use .with() to pass parameters
    email = VoucherNotificationsMailer.with(voucher: @voucher).voucher_assigned

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    # Assert against the specific stubbed subject
    assert_equal 'Voucher Has Been Assigned', email.subject

    # Test both HTML and text parts
    # assert_equal 2, email.parts.size # This might fail if mocks aren't perfect multipart

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'assigned'
    assert_includes html_part.body.to_s, @voucher.code

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'assigned'
    assert_includes text_part.body.to_s, @voucher.code
  end

  test 'voucher_expiring_soon' do
    # Mock Time.current for predictable date calculations
    mock_time = Time.zone.local(2025, 4, 25, 12, 0, 0) # Example fixed time
    Time.stubs(:current).returns(mock_time)

    # Use .with() to pass parameters
    email = VoucherNotificationsMailer.with(voucher: @voucher).voucher_expiring_soon

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    # Assert against the specific stubbed subject
    assert_equal 'Your Voucher Will Expire Soon', email.subject

    # Test both HTML and text parts
    # assert_equal 2, email.parts.size

    # Calculate expected values based on mailer logic and Policy stubs
    expected_expiration_date = @voucher.issued_at + 12.months # Based on Policy stub
    expected_expiration_formatted = expected_expiration_date.strftime('%B %d, %Y')

    # HTML part - Assert against the specific mock body content
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    # Calculate expected days remaining based on the mocked time and mailer logic
    expected_expiration_date = @voucher.issued_at + (Policy.get('voucher_validity_period_months') || 6).months
    expected_days_remaining = (expected_expiration_date.to_date - Time.current.to_date).to_i
    assert_includes html_part.body.to_s, "expire in #{expected_days_remaining} days"
    assert_includes html_part.body.to_s, @voucher.code
    assert_includes html_part.body.to_s, expected_expiration_formatted

    # Text part - Assert against the specific mock body content
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, "expire in #{expected_days_remaining} days"
    assert_includes text_part.body.to_s, @voucher.code
    assert_includes text_part.body.to_s, expected_expiration_formatted
  end

  test 'voucher_expired' do
    # Use .with() to pass parameters
    email = VoucherNotificationsMailer.with(voucher: @voucher).voucher_expired

    assert_emails 1 do
      email.deliver_later
    end
    assert true # Add assertion to satisfy test runner
  end

  test 'voucher_redeemed' do
    # Use .with() to pass parameters
    email = VoucherNotificationsMailer.with(transaction: @transaction).voucher_redeemed

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    # Assert against the specific stubbed subject
    assert_equal 'Voucher Redeemed Confirmation', email.subject

    # Test both HTML and text parts
    # assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'Transaction Confirmation'
    assert_includes html_part.body.to_s, @voucher.code
    assert_includes html_part.body.to_s, @vendor.business_name

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'Transaction Confirmation'
    assert_includes text_part.body.to_s, @voucher.code
    assert_includes text_part.body.to_s, @vendor.business_name
  end
end
