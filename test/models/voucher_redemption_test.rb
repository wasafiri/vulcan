require "test_helper"

class VoucherRedemptionTest < ActiveSupport::TestCase
  def setup
    # Create a constituent, application, voucher, vendor, and multiple products
    @constituent = User.create!(
      first_name: "John",
      last_name: "Doe",
      type: "Constituent",
      email: "john.doe.#{SecureRandom.hex(4)}@example.com", # Use unique email
      password: "password",
      password_confirmation: "password"
    )
    # Add required fields for application validation
    @constituent.update!(
      vision_disability: true, # Add at least one disability
      hearing_disability: true,
      mobility_disability: true
    )

    @application = Application.create!(
      user: @constituent,
      application_date: Time.current,
      status: "draft", # Use draft to avoid medical provider validations
      maryland_resident: true,
      household_size: 3,
      annual_income: 30000,
      self_certify_disability: true,
      medical_provider_name: "Dr. Test",
      medical_provider_email: "doctor@example.com",
      medical_provider_phone: "555-123-4567"
    )
    @voucher = Voucher.create!(
      application: @application,
      initial_value: 100.00,
      remaining_value: 100.00,
      issued_at: Time.current,
      status: "active"
    )
    @vendor = Vendor.create!(
      first_name: "Vendor",
      last_name: "Owner",
      email: "vendor.#{SecureRandom.hex(4)}@example.com", # Use unique email
      password: "password",
      password_confirmation: "password",
      status: "approved",
      business_name: "Test Business",
      business_tax_id: "123456789",
      terms_accepted_at: Time.current,
      w9_status: "approved"
    )

    # Create multiple products for testing
    @product1 = Product.create!(
      name: "Test Product 1",
      manufacturer: "Test Manufacturer",
      model_number: "TP-1",
      device_types: [ "Smartphone" ],
      price: 30.0,
      description: "A product for testing purposes"
    )

    @product2 = Product.create!(
      name: "Test Product 2",
      manufacturer: "Test Manufacturer",
      model_number: "TP-2",
      device_types: [ "Tablet" ],
      price: 45.0,
      description: "Another product for testing purposes"
    )

    @product3 = Product.create!(
      name: "Test Product 3",
      manufacturer: "Test Manufacturer",
      model_number: "TP-3",
      device_types: [ "Captioned Phone" ],
      price: 60.0,
      description: "A third product for testing purposes"
    )
  end

  test "voucher redemption reduces remaining value and creates a voucher transaction" do
    initial_remaining = @voucher.remaining_value
    redemption_amount = 50.0
    product_data = { @product1.id.to_s => 2 }  # Redeeming with 2 units

    txn = @voucher.redeem!(redemption_amount, @vendor, product_data)
    assert txn, "Voucher redemption should return a transaction"

    @voucher.reload
    assert_equal initial_remaining - redemption_amount, @voucher.remaining_value, "Remaining value should be reduced accordingly"
    assert_equal redemption_amount, txn.amount, "Transaction amount should match redeemed amount"
  end

  test "voucher redemption creates voucher_transaction_products and associates product with application" do
    redemption_amount = 30.0
    product_data = { @product1.id.to_s => 1 }

    txn = @voucher.redeem!(redemption_amount, @vendor, product_data)
    assert_not_empty txn.voucher_transaction_products, "Voucher transaction products should be created"

    vtp = txn.voucher_transaction_products.first
    assert_equal @product1.id, vtp.product_id, "Voucher transaction product should reference the correct product"

    @application.reload
    assert_includes @application.products, @product1, "Application should be associated with the redeemed product"
  end

  test "voucher redemption with multiple products creates correct transaction products" do
    redemption_amount = 75.0
    product_data = {
      @product1.id.to_s => 1,  # 1 x $30 = $30
      @product2.id.to_s => 1   # 1 x $45 = $45
    }

    # Total product value: $75

    txn = @voucher.redeem!(redemption_amount, @vendor, product_data)

    # Verify transaction amount
    assert_equal redemption_amount, txn.amount

    # Verify transaction products
    assert_equal 2, txn.voucher_transaction_products.count

    # Check product quantities
    product1_txn = txn.voucher_transaction_products.find_by(product_id: @product1.id)
    product2_txn = txn.voucher_transaction_products.find_by(product_id: @product2.id)

    assert_equal 1, product1_txn.quantity
    assert_equal 1, product2_txn.quantity

    # Verify application products association
    @application.reload
    assert_includes @application.products, @product1
    assert_includes @application.products, @product2
  end

  test "voucher redemption with different product quantities" do
    redemption_amount = 90.0
    product_data = {
      @product1.id.to_s => 3  # 3 x $30 = $90
    }

    txn = @voucher.redeem!(redemption_amount, @vendor, product_data)

    # Verify transaction amount
    assert_equal redemption_amount, txn.amount

    # Verify transaction product quantity
    product_txn = txn.voucher_transaction_products.first
    assert_equal 3, product_txn.quantity

    # Verify remaining voucher balance
    @voucher.reload
    assert_equal 10.0, @voucher.remaining_value
  end

  test "voucher redemption updates application products correctly" do
    # Verify the application doesn't have any products yet
    assert_empty @application.products

    # Redeem voucher with product
    redemption_amount = 30.0
    product_data = { @product1.id.to_s => 1 }

    @voucher.redeem!(redemption_amount, @vendor, product_data)

    # Verify application has the product
    @application.reload
    assert_includes @application.products, @product1

    # Redeem the same voucher again with a different product
    redemption_amount = 45.0
    product_data = { @product2.id.to_s => 1 }

    @voucher.redeem!(redemption_amount, @vendor, product_data)

    # Verify application now has both products
    @application.reload
    assert_includes @application.products, @product1
    assert_includes @application.products, @product2
    assert_equal 2, @application.products.count
  end

  test "voucher is marked as redeemed when fully used" do
    # Redeem the full voucher amount
    redemption_amount = 100.0
    product_data = { @product3.id.to_s => 1, @product1.id.to_s => 1 }  # $60 + $30 = $90

    txn = @voucher.redeem!(redemption_amount, @vendor, product_data)
    assert txn, "Voucher redemption should return a transaction"

    # Verify the voucher is marked as redeemed
    @voucher.reload
    assert_equal 0.0, @voucher.remaining_value
    assert @voucher.voucher_redeemed?, "Voucher should be marked as redeemed when fully used"
  end

  test "voucher cannot be redeemed beyond available balance" do
    # Try to redeem more than the voucher balance
    redemption_amount = 150.0
    product_data = { @product1.id.to_s => 5 }  # 5 x $30 = $150

    # This should not allow redemption
    assert_not @voucher.can_redeem?(redemption_amount), "Voucher should not allow redemption beyond available balance"

    # Trying to redeem should return false
    assert_not @voucher.redeem!(redemption_amount, @vendor, product_data), "Redemption beyond available balance should fail"

    # Voucher should remain unchanged
    @voucher.reload
    assert_equal 100.0, @voucher.remaining_value
  end
end
