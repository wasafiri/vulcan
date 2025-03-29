# frozen_string_literal: true

# Test script to verify STI functionality with User subclasses

require_relative '../config/environment'
require 'minitest/autorun'

class StiUserTest < Minitest::Test
  def test_administrator_resolution
    # Test creating a new instance directly with random email to avoid conflicts
    admin = Users::Administrator.create!(
      email: "test-admin-#{Time.now.to_i}@example.com",
      first_name: "Test",
      last_name: "Admin",
      password: "password123",
      password_confirmation: "password123"
    )
    
    # Test that the class is properly set
    assert_equal Users::Administrator, admin.class
    
    # Test finding an instance and verify class type
    loaded_admin = User.find(admin.id)
    assert_instance_of Users::Administrator, loaded_admin
    
    # Test that admin? method works
    assert loaded_admin.admin?
    
    # Clean up
    admin.destroy
  end
  
  def test_constituent_resolution
    # Test another user type to ensure mapping works for all user types
    constituent = Users::Constituent.create!(
      email: "test-constituent-#{Time.now.to_i}@example.com",
      first_name: "Test",
      last_name: "Constituent",
      password: "password123",
      password_confirmation: "password123"
    )
    
    # Test that the class is properly set
    assert_equal Users::Constituent, constituent.class
    
    # Test finding an instance and verify class type
    loaded_constituent = User.find(constituent.id)
    assert_instance_of Users::Constituent, loaded_constituent
    
    # Test that constituent? method works
    assert loaded_constituent.constituent?
    
    # Clean up
    constituent.destroy
  end
end
