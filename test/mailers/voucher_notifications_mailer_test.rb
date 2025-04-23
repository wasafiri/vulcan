# frozen_string_literal: true

require 'test_helper'

class VoucherNotificationsMailerTest < ActionMailer::TestCase
  setup do
    # Create test data using FactoryBot
    @application = create(:application)
    @user = @application.user
    # Set issued_at to 6 months ago - the expiration_date will be calculated using the Policy
    @voucher = create(:voucher,
                      application: @application,
                      issued_at: 6.months.ago)

    # Stub the Policy.get method to return the appropriate values for testing
    Policy.stubs(:get).with('voucher_validity_period_months').returns(12)
    Policy.stubs(:get).with('voucher_minimum_redemption_amount').returns(10)
    Policy.stubs(:voucher_validity_period).returns(12.months)
    @vendor = create(:vendor, :approved)
    @transaction = create(:voucher_transaction,
                          voucher: @voucher,
                          vendor: @vendor,
                          status: :transaction_completed,
                          amount: 100.00)
  end

  test 'voucher_assigned' do
    email = VoucherNotificationsMailer.voucher_assigned(@voucher)

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_match 'Voucher Has Been Assigned', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

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
    email = VoucherNotificationsMailer.voucher_expiring_soon(@voucher)

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_match 'Expire Soon', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'expire'
    assert_includes html_part.body.to_s, @voucher.code

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'expire'
    assert_includes text_part.body.to_s, @voucher.code
  end

  test 'voucher_expired' do
    email = VoucherNotificationsMailer.voucher_expired(@voucher)

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_match 'Expired', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'expired'
    assert_includes html_part.body.to_s, @voucher.code

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'expired'
    assert_includes text_part.body.to_s, @voucher.code
  end

  test 'voucher_redeemed' do
    email = VoucherNotificationsMailer.voucher_redeemed(@transaction)

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_match 'Redeemed', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

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
