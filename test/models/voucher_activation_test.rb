require "test_helper"

class VoucherActivationTest < ActiveSupport::TestCase
  test "activate_if_valid! activates an issued voucher" do
    voucher = FactoryBot.create(:voucher, status: :issued)

    voucher.activate_if_valid!
    assert_equal "active", voucher.status
  end

  test "activate_if_valid! marks an expired voucher as expired" do
    expiration_period = Policy.voucher_validity_period
    voucher = FactoryBot.create(:voucher,
      status: :issued,
      issued_at: Time.current - expiration_period - 1.day
    )

    voucher.activate_if_valid!
    assert_equal "expired", voucher.status
  end

  test "activate_if_valid! does not change active vouchers" do
    voucher = FactoryBot.create(:voucher, :active)

    original_updated_at = voucher.updated_at
    voucher.activate_if_valid!

    assert_equal "active", voucher.status
    # Ensure the record wasn't updated
    assert_equal original_updated_at, voucher.reload.updated_at
  end

  test "activate_if_valid! does not change redeemed vouchers" do
    voucher = FactoryBot.create(:voucher, :redeemed)

    original_updated_at = voucher.updated_at
    voucher.activate_if_valid!

    assert_equal "redeemed", voucher.status
    # Ensure the record wasn't updated
    assert_equal original_updated_at, voucher.reload.updated_at
  end

  test "activate_if_valid! does not change cancelled vouchers" do
    voucher = FactoryBot.create(:voucher, :cancelled)

    original_updated_at = voucher.updated_at
    voucher.activate_if_valid!

    assert_equal "cancelled", voucher.status
    # Ensure the record wasn't updated
    assert_equal original_updated_at, voucher.reload.updated_at
  end
end
