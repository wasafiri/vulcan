# frozen_string_literal: true

require 'test_helper'

class VendorTest < ActiveSupport::TestCase
  test 'valid vendor can be created with factory' do
    vendor = create(:vendor, :approved, :with_w9) # Use :with_w9 trait to attach a W9, which sets it to in_progress

    assert vendor.valid?
    assert_equal 'Users::Vendor', vendor.type
    assert vendor.vendor_approved?
    
    # Use update_column to bypass callbacks that might reset w9_status
    vendor.update_column(:w9_status, :approved) # Ensure W9 status is approved for can_process_vouchers?
    assert vendor.can_process_vouchers?
  end
end
