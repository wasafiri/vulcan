# frozen_string_literal: true

require 'test_helper'

class VoucherStatusTest < ActiveSupport::TestCase
  test 'voucher activation from active state' do
    voucher = FactoryBot.create(:voucher, status: :active)

    # Verify initial state
    assert_equal 'active', voucher.status

    # Call the activate_if_valid! method
    voucher.activate_if_valid!

    # Status should still be active
    assert_equal 'active', voucher.status
  end

  test "voucher status enum doesn't contain issued" do
    # Verify that the status enum doesn't contain 'issued'
    assert_not Voucher.statuses.key?('issued')
  end

  test 'voucher default status is active' do
    # Create a voucher without specifying status
    voucher = FactoryBot.create(:voucher)

    # Default status should be active
    assert_equal 'active', voucher.status
  end
end
