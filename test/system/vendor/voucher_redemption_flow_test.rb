# frozen_string_literal: true

require 'application_system_test_case'

module VendorPortal
  class VoucherRedemptionFlowTest < ApplicationSystemTestCase
    def setup
      # Create vendor with proper approvals to process vouchers
      @vendor = create(:vendor, :approved)

      # Vendor is already set up with approved status and W9 form from seeded data

      # Create constituent who will receive the voucher
      @constituent = User.create!(
        first_name: 'Alice',
        last_name: 'Wonder',
        type: 'Constituent',
        email: 'alice@example.com',
        password: 'password',
        password_confirmation: 'password',
        date_of_birth: 25.years.ago.to_date,
        vision_disability: true,
        hearing_disability: true,
        mobility_disability: false,
        cognition_disability: false,
        speech_disability: false
      )

      # Create application for the constituent
      @application = create(:application,
                            user: @constituent,
                            status: 'in_progress',
                            household_size: 1,
                            annual_income: 25_000,
                            medical_provider_name: 'Dr. Test Provider',
                            medical_provider_email: 'doctor@example.com',
                            medical_provider_phone: '555-123-4567')

      # Create voucher with a fixed code for testing
      @voucher = Voucher.new(
        application: @application,
        initial_value: 100.00,
        remaining_value: 100.00,
        issued_at: Time.current,
        status: 'active'
      )
      # Set a fixed code for testing
      @voucher.code = 'TESTVOUCHER123'
      @voucher.save!

      # Create test products with different prices
      @product1 = Product.create!(
        name: 'System Test Product 1',
        manufacturer: 'Test Manufacturer',
        model_number: 'STP-1',
        device_types: ['Tablet'],
        price: 20.0,
        description: 'A product for system testing'
      )

      @product2 = Product.create!(
        name: 'System Test Product 2',
        manufacturer: 'Test Manufacturer',
        model_number: 'STP-2',
        device_types: ['Smartphone'],
        price: 35.0,
        description: 'Another product for system testing'
      )

      # Create an invalid voucher code for testing error cases
      @invalid_voucher_code = 'INVALIDCODE12345'
    end

    test 'vendor redeems voucher through the UI flow' do
      # Sign in as vendor
      sign_in_as_vendor

      # Navigate to the voucher redemption page (will redirect to verification first)
      visit redeem_vendor_voucher_path(@voucher.code)

      # Should be redirected to verification page
      assert_text 'Identity Verification'
      assert_text @voucher.code

      # Complete verification with constituent's date of birth
      fill_in 'date_of_birth', with: @constituent.date_of_birth.strftime('%Y-%m-%d')
      click_button 'Verify Identity'

      # Now should be on redemption page
      assert_text 'Voucher Redemption'
      assert_text @voucher.code

      # Fill in redemption details - partial amount of the voucher
      find_by_id('redemption-amount').set('50.0')
      check "product_#{@product1.id}"
      click_button 'Process Redemption'
      assert_text 'Successfully processed voucher'

      # Verify the voucher and application were updated
      @voucher.reload
      @application.reload
      assert_equal 50.0, @voucher.remaining_value
      assert_includes @application.products, @product1
    end

    test 'vendor can verify a valid voucher code' do
      sign_in_as_vendor
      visit vendor_vouchers_path

      fill_in 'voucher_code', with: @voucher.code
      click_button 'Verify Voucher'

      # Should be redirected to verification page first
      assert_current_path verify_vendor_voucher_path(@voucher.code)
      assert_text 'Identity Verification'
    end

    test 'vendor sees error when verifying an invalid voucher code' do
      sign_in_as_vendor
      visit vendor_vouchers_path

      fill_in 'voucher_code', with: @invalid_voucher_code
      click_button 'Verify Voucher'

      assert_text 'Invalid voucher code'
      assert_current_path vendor_vouchers_path
    end

    test 'vendor can select multiple products with different quantities' do
      sign_in_as_vendor
      visit redeem_vendor_voucher_path(@voucher.code)

      # Complete verification first
      assert_text 'Identity Verification'
      fill_in 'date_of_birth', with: @constituent.date_of_birth.strftime('%Y-%m-%d')
      click_button 'Verify Identity'

      # Verify we're on the redemption page
      assert_text 'Voucher Redemption'

      # Select products
      check "product_#{@product1.id}"
      check "product_#{@product2.id}"

      # Calculate expected total: $20 + $35 = $55 (assuming quantity of 1 for each selected product)
      expected_total = @product1.price + @product2.price

      # Enter the redemption amount to match product total
      find_by_id('redemption-amount').set(expected_total.to_s)

      click_button 'Process Redemption'
      assert_text 'Successfully processed voucher'

      # Verify the association was created for both products
      @application.reload
      assert_includes @application.products, @product1
      assert_includes @application.products, @product2

      # Verify the voucher balance was reduced correctly
      @voucher.reload
      assert_equal 100.0 - expected_total, @voucher.remaining_value
    end

    test 'vendor cannot submit redemption without selecting products' do
      sign_in_as_vendor
      visit redeem_vendor_voucher_path(@voucher.code)

      # Complete verification first
      assert_text 'Identity Verification'
      fill_in 'date_of_birth', with: @constituent.date_of_birth.strftime('%Y-%m-%d')
      click_button 'Verify Identity'
      assert_text 'Voucher Redemption'

      # Try to submit without selecting any products
      find_by_id('redemption-amount').set('50.0')

      # The button should be disabled, so we need to force the form submission
      page.execute_script("document.getElementById('redemption-form').submit()")

      # Should stay on the same page with an error
      assert_text 'Please select at least one product for this voucher redemption'
      assert_current_path redeem_vendor_voucher_path(@voucher.code)

      # Voucher should remain unchanged
      @voucher.reload
      assert_equal 100.0, @voucher.remaining_value
    end

    test 'vendor cannot redeem more than voucher balance' do
      sign_in_as_vendor
      visit redeem_vendor_voucher_path(@voucher.code)

      # Complete verification first
      assert_text 'Identity Verification'
      fill_in 'date_of_birth', with: @constituent.date_of_birth.strftime('%Y-%m-%d')
      click_button 'Verify Identity'
      assert_text 'Voucher Redemption'

      # Try to submit with amount greater than balance
      find_by_id('redemption-amount').set('150.0')
      check "product_#{@product1.id}"

      # Submit the form
      click_button 'Process Redemption'

      # Should stay on same page with an error
      assert_text 'Amount exceeds remaining voucher balance'
      assert_current_path redeem_vendor_voucher_path(@voucher.code)

      # Voucher should remain unchanged
      @voucher.reload
      assert_equal 100.0, @voucher.remaining_value
    end

    private

    def sign_in_as_vendor
      sign_in(@vendor)
      visit vendor_dashboard_path
      assert_text 'Vendor Dashboard'
    end
  end
end
