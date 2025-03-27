# frozen_string_literal: true

require 'application_system_test_case'

class VendorVoucherRedemptionFlowTest < ApplicationSystemTestCase
  def setup
    # Create vendor with proper approvals to process vouchers
    @vendor = Vendor.create!(
      first_name: 'Vendor',
      last_name: 'Flow',
      email: 'vendor.flow@example.com',
      password: 'password',
      password_confirmation: 'password',
      status: 'approved',
      business_name: 'Flow Business',
      business_tax_id: '111222333',
      terms_accepted_at: Time.current,
      w9_status: 'approved'
    )

    # Attach a W9 form to the vendor to pass validation for can_process_vouchers?
    @vendor.w9_form.attach(
      io: File.open(file_fixture('sample_w9.pdf')),
      filename: 'sample_w9.pdf',
      content_type: 'application/pdf'
    )

    # Ensure the W9 status is approved
    @vendor.update!(w9_status: :approved)

    # Create constituent who will receive the voucher
    @constituent = User.create!(
      first_name: 'Alice',
      last_name: 'Wonder',
      type: 'Constituent',
      email: 'alice@example.com',
      password: 'password',
      password_confirmation: 'password',
      vision_disability: true,
      hearing_disability: true,
      mobility_disability: false,
      cognition_disability: false,
      speech_disability: false
    )

    # Create application for the constituent
    @application = Application.create!(
      user: @constituent,
      application_date: Time.current,
      status: 'in_progress',
      maryland_resident: true,
      household_size: 1,
      annual_income: 25_000,
      self_certify_disability: true,
      medical_provider_name: 'Dr. Test Provider',
      medical_provider_email: 'doctor@example.com',
      medical_provider_phone: '555-123-4567'
    )

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

    # Navigate directly to the voucher redemption page
    visit redeem_vendor_voucher_path(@voucher.code)
    assert_text 'Voucher Redemption'
    assert_text @voucher.code

    # Fill in redemption details - partial amount of the voucher
    find('#redemption-amount').set('50.0')
    check "product_#{@product1.id}"
    find("#quantity_#{@product1.id}").set('1')

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

    assert_current_path redeem_vendor_voucher_path(@voucher.code)
    assert_text 'Voucher Redemption'
    assert_text @voucher.code
    assert_text '$100.00' # Current balance
  end

  test 'vendor sees error when verifying an invalid voucher code' do
    sign_in_as_vendor
    visit vendor_vouchers_path

    fill_in 'voucher_code', with: @invalid_voucher_code
    click_button 'Verify Voucher'

    assert_text 'Invalid voucher code'
    assert_current_path vendor_dashboard_path
  end

  test 'vendor can select multiple products with different quantities' do
    sign_in_as_vendor
    visit redeem_vendor_voucher_path(@voucher.code)

    # Verify we're on the redemption page
    assert_text 'Voucher Redemption'

    # Select products with quantities
    check "product_#{@product1.id}"
    find("#quantity_#{@product1.id}").set('2')

    check "product_#{@product2.id}"
    find("#quantity_#{@product2.id}").set('1')

    # Calculate expected total: 2 x $20 + 1 x $35 = $75
    expected_total = (2 * @product1.price) + (1 * @product2.price)

    # Enter the redemption amount to match product total
    find('#redemption-amount').set(expected_total.to_s)

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

    # Try to submit without selecting any products
    find('#redemption-amount').set('50.0')

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

    # Try to submit with amount greater than balance
    find('#redemption-amount').set('150.0')
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
    visit sign_in_path
    fill_in 'Email', with: @vendor.email
    fill_in 'Password', with: 'password'
    find('input[type="submit"][value="Sign In"]').click
    assert_text 'Vendor Dashboard'
  end
end
