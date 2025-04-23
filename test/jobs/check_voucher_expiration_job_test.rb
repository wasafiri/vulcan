# frozen_string_literal: true

require 'test_helper'

class CheckVoucherExpirationJobTest < ActiveJob::TestCase
  setup do
    # Create a stub for the legacy pending_activation method that's not in the current model
    Voucher.stubs(:pending_activation).returns(Voucher.none)

    # Set up mailer mocks for verification
    @expiring_soon_mail_mock = mock('mail')
    @expiring_soon_mail_mock.expects(:deliver_later).at_most_once

    @expired_mail_mock = mock('mail')
    @expired_mail_mock.expects(:deliver_later).at_most_once

    @expiring_today_mail_mock = mock('mail')
    @expiring_today_mail_mock.expects(:deliver_later).at_most_once

    # Stub the actual mailer methods
    VoucherNotificationsMailer.stubs(:voucher_expiring_soon).returns(@expiring_soon_mail_mock)
    VoucherNotificationsMailer.stubs(:voucher_expired).returns(@expired_mail_mock)
    VoucherNotificationsMailer.stubs(:voucher_expiring_today).returns(@expiring_today_mail_mock)

    # Mock event creation to avoid DB dependency
    @events_mock = mock('events')
    @events_mock.stubs(:create!).returns(true)
    Voucher.any_instance.stubs(:events).returns(@events_mock)

    # Prepare a Policy value that will be used
    Policy.stubs(:get).with('voucher_validity_period_months').returns(3)
  end

  teardown do
    Voucher.unstub(:pending_activation)
    VoucherNotificationsMailer.unstub(:voucher_expiring_soon)
    VoucherNotificationsMailer.unstub(:voucher_expired)
    VoucherNotificationsMailer.unstub(:voucher_expiring_today)
    Voucher.any_instance.unstub(:events)
    Policy.unstub(:get)
  end

  test 'identifies vouchers expiring soon and sends notifications' do
    application = FactoryBot.create(:application, :completed)

    # Create a voucher that's expiring in ~7 days (adjust the issued_at)
    expiration_threshold = 7.days
    issued_at = 3.months.ago + expiration_threshold

    # Expect the expiring_soon notification to be triggered
    VoucherNotificationsMailer.expects(:voucher_expiring_soon).once.returns(@expiring_soon_mail_mock)

    Voucher.create!(
      application: application,
      code: 'TEST12345678',
      initial_value: 500,
      remaining_value: 500,
      status: :active,
      issued_at: issued_at
    )

    # Run the job
    CheckVoucherExpirationJob.perform_now
  end

  test 'marks expired vouchers as expired and sends notification' do
    # We need to stub the original check_status_changes method to prevent automatic notifications
    # This is because the job code AND the voucher model both try to send notifications
    Voucher.any_instance.stubs(:check_status_changes).returns(nil)

    # Create a voucher in active status that is expired
    application = FactoryBot.create(:application, :completed)
    voucher = Voucher.create!(
      application: application,
      code: 'TEST87654321',
      initial_value: 500,
      remaining_value: 500,
      status: :active,
      issued_at: 3.months.ago - 1.day # Definitely expired
    )

    # Set up expectation for the specific voucher
    expired_mail = mock('expired_mail')
    expired_mail.expects(:deliver_later).once

    # This expectation is specifically for our voucher - must be with the same object
    VoucherNotificationsMailer.expects(:voucher_expired)
                              .with { |v| v.id == voucher.id } # Match by ID
                              .once
                              .returns(expired_mail)

    # Verify it starts as active
    assert_equal 'active', voucher.status

    # Run the job
    CheckVoucherExpirationJob.perform_now

    # Reload the voucher and check its status
    voucher.reload
    assert_equal 'expired', voucher.status
  end

  test 'does not change active vouchers that are not expired' do
    # For this test, we expect voucher_expired to NOT be called
    VoucherNotificationsMailer.unstub(:voucher_expired)
    VoucherNotificationsMailer.expects(:voucher_expired).never

    # Ensure the non-expiring voucher doesn't get any expiring_soon notification
    VoucherNotificationsMailer.unstub(:voucher_expiring_soon)
    VoucherNotificationsMailer.expects(:voucher_expiring_soon).never

    # Create a voucher in active status that is not expired (very recent)
    application = FactoryBot.create(:application, :completed)
    voucher = Voucher.create!(
      application: application,
      code: 'TESTACTIVE123',
      initial_value: 500,
      remaining_value: 500,
      status: :active,
      issued_at: 1.day.ago # Very recent
    )

    # Verify it starts as active
    assert_equal 'active', voucher.status

    # Run the job
    CheckVoucherExpirationJob.perform_now

    # Reload the voucher and check its status - should still be active
    voucher.reload
    assert_equal 'active', voucher.status, 'Voucher should remain active if not expired'
  end
end
