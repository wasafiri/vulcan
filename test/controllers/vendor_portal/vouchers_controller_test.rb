# frozen_string_literal: true

require 'test_helper'

module VendorPortal
  class VouchersControllerTest < ActionDispatch::IntegrationTest
    def setup
      @vendor = users(:vendor_raz) # Use fixture instead of factory
      @voucher = vouchers(:valid_voucher) # Use fixture

      # Set standard test headers
      @headers = {
        'HTTP_USER_AGENT' => 'Rails Testing',
        'REMOTE_ADDR' => '127.0.0.1'
      }

      post sign_in_path,
           params: { email: @vendor.email, password: 'password123' },
           headers: @headers

      assert_response :redirect
      follow_redirect!
    end

    def test_get_index
      get vendor_portal_vouchers_path
      assert_response :success
    end

    def test_get_redeem
      get redeem_vendor_portal_voucher_path(@voucher.code)
      assert_response :success
    end

    def test_process_redemption_with_valid_amount
      # Assuming the voucher has enough balance and the vendor can process vouchers
      @vendor.update(vendor_approved: true)
      @voucher.update(status: :active, amount: 500.0, redeemed_amount: 0.0)

      assert_difference 'VoucherTransaction.count', 1 do
        post process_redemption_vendor_portal_voucher_path(@voucher.code),
             params: { amount: 100.0, product_ids: [] }
      end

      assert_redirected_to vendor_portal_dashboard_path
      @voucher.reload
      assert_equal 100.0, @voucher.redeemed_amount
    end

    def test_process_redemption_with_invalid_amount
      # Set up a valid voucher
      @vendor.update(vendor_approved: true)
      @voucher.update(status: :active, amount: 500.0, redeemed_amount: 0.0)

      # Try to redeem more than the voucher's value
      post process_redemption_vendor_portal_voucher_path(@voucher.code),
           params: { amount: 600.0, product_ids: [] }

      assert_redirected_to redeem_vendor_portal_voucher_path(@voucher.code)
      assert_not_nil flash[:alert]
    end
  end
end
