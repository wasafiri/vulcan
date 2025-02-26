require "test_helper"

class CheckVoucherExpirationJobTest < ActiveJob::TestCase
  test "activates issued vouchers" do
    # Create a voucher in issued status
    application = FactoryBot.create(:application, :completed)
    voucher = Voucher.create!(
      application: application,
      code: "TEST12345678",
      initial_value: 500,
      remaining_value: 500,
      status: :issued,
      issued_at: Time.current
    )

    # Run the job
    CheckVoucherExpirationJob.perform_now

    # Reload the voucher and check its status
    voucher.reload
    assert_equal "active", voucher.status
  end

  test "marks expired vouchers as expired" do
    # Create a voucher in issued status that is expired
    application = FactoryBot.create(:application, :completed)
    expiration_period = Policy.voucher_validity_period
    voucher = Voucher.create!(
      application: application,
      code: "TEST87654321",
      initial_value: 500,
      remaining_value: 500,
      status: :issued,
      issued_at: Time.current - expiration_period - 1.day
    )

    # Run the job
    CheckVoucherExpirationJob.perform_now

    # Reload the voucher and check its status
    voucher.reload
    assert_equal "expired", voucher.status
  end

  test "does not change active vouchers that are not expired" do
    # Create a voucher in active status that is not expired
    application = FactoryBot.create(:application, :completed)
    voucher = Voucher.create!(
      application: application,
      code: "TESTACTIVE123",
      initial_value: 500,
      remaining_value: 500,
      status: :active,
      issued_at: Time.current
    )

    # Run the job
    CheckVoucherExpirationJob.perform_now

    # Reload the voucher and check its status
    voucher.reload
    assert_equal "active", voucher.status
  end
end
