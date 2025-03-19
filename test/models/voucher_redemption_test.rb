# frozen_string_literal: true

require 'test_helper'

class VoucherRedemptionTest < ActiveSupport::TestCase
  setup do
    @application = applications(:complete)
    @constituent = users(:constituent)
    @vendor = users(:vendor)
    
    # Create a test voucher
    @voucher = Voucher.create!(
      application: @application,
      initial_value: 500,
      remaining_value: 500,
      issued_at: Time.current
    )
  end

  test "voucher redemption creates transaction record" do
    assert_difference -> { VoucherTransaction.count }, 1 do
      @voucher.redeem!(100, @vendor)
    end
    
    txn = VoucherTransaction.last
    assert_equal 100, txn.amount
    assert_equal @vendor, txn.vendor
    assert_equal 'redemption', txn.transaction_type
    assert_equal 'transaction_completed', txn.status
  end

  test "voucher redemption updates voucher remaining value" do
    @voucher.redeem!(100, @vendor)
    @voucher.reload
    
    assert_equal 400, @voucher.remaining_value
    assert_equal @vendor, @voucher.vendor
    assert_not_nil @voucher.last_used_at
  end

  test "voucher redemption creates event record" do
    assert_difference -> { Event.count }, 1 do
      @voucher.redeem!(100, @vendor)
    end
    
    event = Event.last
    assert_equal 'voucher_redeemed', event.action
    assert_equal @vendor, event.user
    
    # Check metadata contains expected values
    assert_equal @application.id, event.metadata['application_id']
    assert_equal @voucher.code, event.metadata['voucher_code']
    assert_equal 100, event.metadata['amount']
    assert_equal @vendor.business_name, event.metadata['vendor_name']
    assert_not_nil event.metadata['transaction_id']
    assert_equal 400, event.metadata['remaining_value']
  end
  
  test "voucher redemption sends email notification" do
    assert_enqueued_emails 1 do
      @voucher.redeem!(100, @vendor)
    end
  end
  
  test "voucher redemption with products associates products" do
    product1 = products(:one)
    product2 = products(:two)
    product_data = { product1.id.to_s => 1, product2.id.to_s => 2 }
    
    @voucher.redeem!(100, @vendor, product_data)
    
    # Check that products are associated with application
    assert_includes @application.products, product1
    assert_includes @application.products, product2
    
    # Check that products are associated with transaction
    txn = VoucherTransaction.last
    assert_equal 2, txn.voucher_transaction_products.count
    
    # Check product metadata in event
    event = Event.last
    assert_not_nil event.metadata['products']
    assert_equal 2, event.metadata['products'].size
  end
  
  test "fault-tolerant event logging doesn't prevent redemption" do
    # Setup mock to simulate an error when creating an event
    Event.any_instance.expects(:save!).raises(StandardError, "Simulated error")
    
    # Redemption should still succeed
    assert_difference -> { VoucherTransaction.count }, 1 do
      @voucher.redeem!(100, @vendor)
    end
    
    # Voucher should still be updated
    @voucher.reload
    assert_equal 400, @voucher.remaining_value
  end
  
  test "full redemption sets voucher status to redeemed" do
    @voucher.redeem!(@voucher.remaining_value, @vendor)
    @voucher.reload
    
    assert_equal 'redeemed', @voucher.status
    assert_equal 0, @voucher.remaining_value
  end
  
  test "cannot redeem more than remaining value" do
    result = @voucher.redeem!(@voucher.remaining_value + 1, @vendor)
    assert_equal false, result
    
    @voucher.reload
    assert_equal 500, @voucher.remaining_value
  end
  
  test "cannot redeem below minimum amount" do
    min_amount = Policy.voucher_minimum_redemption_amount
    result = @voucher.redeem!(min_amount - 0.01, @vendor)
    assert_equal false, result
    
    @voucher.reload
    assert_equal 500, @voucher.remaining_value
  end
end
