# frozen_string_literal: true

require 'test_helper'

class NotificationDecoratorTest < ActiveSupport::TestCase
  setup do
    # Create a mock notification object instead of using fixtures
    @notification = Notification.new(
      id: 1,
      action: "medical_certification_requested",
      created_at: Time.current,
      notifiable_type: "Application",
      notifiable_id: 123
    )
    @decorator = NotificationDecorator.new(@notification)
  end

  test "to_ary does not cause infinite recursion" do
    # This test ensures that array flattening operations don't cause infinite recursion
    assert_nil @decorator.to_ary
    
    # Test that the decorator can be safely used in array operations
    decorators = [@decorator, @decorator]
    assert_nothing_raised { decorators.flatten }
    assert_equal 2, decorators.flatten.size
    
    # Mixed array with decorators and other values
    mixed_array = [@decorator, "string", 123, @decorator]
    flattened = nil
    assert_nothing_raised { flattened = mixed_array.flatten }
    assert_equal 4, flattened.size
  end
  
  test "decorator behaves like its wrapped notification" do
    assert_equal @notification.id, @decorator.id
    assert_equal @notification.action, @decorator.action
    assert_equal @notification.created_at, @decorator.created_at
  end
end
