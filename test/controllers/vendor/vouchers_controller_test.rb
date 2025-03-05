require "test_helper"

class Vendor::VouchersControllerTest < ActionDispatch::IntegrationTest
  # Helper method to sign in a vendor.
  def sign_in_as(vendor)
    post sign_in_path, params: { email: vendor.email, password: "password" }
    assert_response :redirect
    follow_redirect!
    assert_response :success
  end

  def setup
    @vendor = Vendor.create!(
      first_name: "Vendor",
      last_name: "Controller",
      email: "vendor2.#{SecureRandom.hex(4)}@example.com",
      password: "password",
      password_confirmation: "password",
      status: "approved",
      business_name: "Another Test Business",
      business_tax_id: "987654321",
      terms_accepted_at: Time.current,
      w9_status: "approved"
    )

    # Add w9_form to vendor to pass validation for can_process_vouchers?
    attachment = fixture_file_upload("test/fixtures/files/sample_w9.pdf", "application/pdf")
    @vendor.w9_form.attach(attachment)

    @constituent = User.create!(
      first_name: "Jane",
      last_name: "Smith",
      type: "Constituent",
      email: "jane.smith.#{SecureRandom.hex(4)}@example.com",
      password: "password",
      password_confirmation: "password"
    )

    # Add required fields for application validation
    @constituent.update!(
      vision_disability: true,
      hearing_disability: true,
      mobility_disability: true
    )

    @application = Application.create!(
      user: @constituent,
      application_date: Time.current,
      status: "draft", # Use draft to avoid medical provider validations
      maryland_resident: true,
      household_size: 2,
      annual_income: 40000,
      self_certify_disability: true,
      medical_provider_name: "Dr. Controller Test",
      medical_provider_email: "doctor.controller@example.com",
      medical_provider_phone: "555-987-6543"
    )

    @voucher = Voucher.create!(
      application: @application,
      initial_value: 100.00,
      remaining_value: 100.00,
      issued_at: Time.current,
      status: "active"
    )

    @product1 = Product.create!(
      name: "Controller Test Product 1",
      manufacturer: "Test Manufacturer",
      model_number: "CTP-1",
      device_types: [ "Smartphone" ],
      price: 25.0,
      description: "A product created for controller testing"
    )

    @product2 = Product.create!(
      name: "Controller Test Product 2",
      manufacturer: "Test Manufacturer",
      model_number: "CTP-2",
      device_types: [ "Tablet" ],
      price: 35.0,
      description: "Another product created for controller testing"
    )

    sign_in_as(@vendor)
  end

  test "index action renders successfully" do
    get vendor_vouchers_path
    assert_response :success
    assert_select "h1", "Vouchers"
  end

  test "redeem action with valid voucher loads voucher details and products" do
    # Mock Policy.voucher_minimum_redemption_amount
    Policy.stubs(:voucher_minimum_redemption_amount).returns(10.0)

    get redeem_vendor_voucher_path(@voucher.code)
    assert_response :success
    assert_select "h1", "Voucher Redemption"
    assert_select "p", /Voucher Code:/

    # Verify that both products are displayed
    assert_select ".product-item", count: Product.active.count
  end

  test "redeem action with code parameter finds voucher correctly" do
    # Mock Policy.voucher_minimum_redemption_amount
    Policy.stubs(:voucher_minimum_redemption_amount).returns(10.0)

    get redeem_vendor_voucher_path(@voucher.code)
    assert_response :success
    assert_select "p", /#{@voucher.code}/
  end

  test "redeem action with invalid voucher redirects with alert" do
    get redeem_vendor_voucher_path("nonexistent")
    assert_redirected_to vendor_dashboard_path
    follow_redirect!
    assert_not_nil flash[:alert]
    assert_match /Invalid voucher code/, flash[:alert]
  end

  test "process_redemption action processes valid redemption" do
    # Mock Policy.voucher_minimum_redemption_amount
    Policy.stubs(:voucher_minimum_redemption_amount).returns(10.0)

    redemption_amount = 50.0
    product_ids = [ @product1.id ]
    product_quantities = { @product1.id.to_s => "1" }

    post process_redemption_vendor_voucher_path(@voucher.code), params: {
      amount: redemption_amount,
      product_ids: product_ids,
      product_quantities: product_quantities
    }
    assert_redirected_to vendor_dashboard_path
    follow_redirect!
    assert_not_nil flash[:notice]

    @voucher.reload
    assert_equal 50.0, @voucher.remaining_value, "Voucher remaining value should be reduced by the redemption amount"

    # Verify the product is associated with the application
    @application.reload
    assert_includes @application.products, @product1
  end

  test "process_redemption correctly extracts product data" do
    # Mock Policy.voucher_minimum_redemption_amount
    Policy.stubs(:voucher_minimum_redemption_amount).returns(10.0)

    redemption_amount = 60.0
    product_ids = [ @product1.id, @product2.id ]
    product_quantities = {
      @product1.id.to_s => "1",
      @product2.id.to_s => "2"
    }

    post process_redemption_vendor_voucher_path(@voucher.code), params: {
      amount: redemption_amount,
      product_ids: product_ids,
      product_quantities: product_quantities
    }
    assert_redirected_to vendor_dashboard_path

    # Verify the products are associated with the application
    @application.reload
    assert_includes @application.products, @product1
    assert_includes @application.products, @product2

    # Find the transaction and verify product quantities
    transaction = @voucher.transactions.last
    assert_equal 2, transaction.voucher_transaction_products.count

    # Find product quantities in transaction products
    product1_txn = transaction.voucher_transaction_products.find_by(product_id: @product1.id)
    product2_txn = transaction.voucher_transaction_products.find_by(product_id: @product2.id)

    assert_equal 1, product1_txn.quantity
    assert_equal 2, product2_txn.quantity
  end

  test "process_redemption associates products with application" do
    # Mock Policy.voucher_minimum_redemption_amount
    Policy.stubs(:voucher_minimum_redemption_amount).returns(10.0)

    redemption_amount = 25.0
    product_ids = [ @product1.id ]
    product_quantities = { @product1.id.to_s => "1" }

    # Verify the application doesn't have the product yet
    assert_not_includes @application.products, @product1

    post process_redemption_vendor_voucher_path(@voucher.code), params: {
      amount: redemption_amount,
      product_ids: product_ids,
      product_quantities: product_quantities
    }

    # Verify the product is now associated with the application
    @application.reload
    assert_includes @application.products, @product1
  end

  test "process_redemption action fails when no products selected" do
    # Mock Policy.voucher_minimum_redemption_amount
    Policy.stubs(:voucher_minimum_redemption_amount).returns(10.0)

    redemption_amount = 30.0

    post process_redemption_vendor_voucher_path(@voucher.code), params: {
      amount: redemption_amount
      # no product_ids provided
    }
    assert_redirected_to redeem_vendor_voucher_path(@voucher.code)
    follow_redirect!
    assert_not_nil flash[:alert]
    assert_match /select at least one product/, flash[:alert]

    # Verify the voucher value remained unchanged
    @voucher.reload
    assert_equal 100.0, @voucher.remaining_value
  end

  test "process_redemption fails when amount exceeds voucher balance" do
    # Mock Policy.voucher_minimum_redemption_amount
    Policy.stubs(:voucher_minimum_redemption_amount).returns(10.0)

    redemption_amount = 150.0 # Greater than voucher balance
    product_ids = [ @product1.id ]
    product_quantities = { @product1.id.to_s => "1" }

    post process_redemption_vendor_voucher_path(@voucher.code), params: {
      amount: redemption_amount,
      product_ids: product_ids,
      product_quantities: product_quantities
    }

    assert_redirected_to redeem_vendor_voucher_path(@voucher.code)
    follow_redirect!
    assert_not_nil flash[:alert]
    assert_match /exceeds remaining voucher balance/, flash[:alert]

    # Verify the voucher value remained unchanged
    @voucher.reload
    assert_equal 100.0, @voucher.remaining_value
  end
end
