require 'test_helper'

class Vendor::VouchersControllerTest < ActionDispatch::IntegrationTest
  # Include authentication helpers
  include AuthenticationTestHelper
  
  setup do
    @vendor_raz = users(:vendor_raz)
    
    # Reference our voucher fixtures
    @processed_voucher = vouchers(:vendor_raz_voucher)
    @kenneth_voucher = vouchers(:kenneth_voucher)
    @steven_voucher = vouchers(:steven_voucher)
  end
  
  test "vendor can only see their own processed vouchers" do
    log_in_as @vendor_raz
    
    get vendor_vouchers_path
    assert_response :success
    
    # Should see the voucher they processed
    assert_match @processed_voucher.code, response.body
    
    # Should NOT see vouchers they haven't processed
    assert_no_match @kenneth_voucher.code, response.body
    assert_no_match @steven_voucher.code, response.body
  end
  
  # To test the empty state, we'd need an additional vendor with no vouchers
  # Since we don't want to modify the existing fixtures, we could:
  # 1. Create a new vendor in this test
  # 2. Or test this through a different approach
  
  test "index shows appropriate messaging" do
    log_in_as @vendor_raz
    
    get vendor_vouchers_path
    assert_response :success
    
    # The heading should indicate these are processed vouchers
    assert_match "Your Processed Vouchers", response.body
  end
  
  test "redirects to redemption page when valid voucher code is provided" do
    log_in_as @vendor_raz
    
    # Use the kenneth_voucher which the vendor hasn't processed yet
    get vendor_vouchers_path(code: @kenneth_voucher.code)
    
    # Should redirect to the redemption page
    assert_redirected_to redeem_vendor_voucher_path(@kenneth_voucher.code)
  end
  
  test "shows flash error when invalid voucher code is provided" do
    log_in_as @vendor_raz
    
    # Use an invalid voucher code
    get vendor_vouchers_path(code: "INVALID_CODE")
    
    # Should stay on the index page
    assert_response :success
    
    # Should show an error message
    assert_not_nil flash.now[:alert]
  end
end
