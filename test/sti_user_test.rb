# frozen_string_literal: true

# Verify STI functionality with User subclasses

require 'test_helper'

class StiUserTest < ActiveSupport::TestCase
  def test_administrator_resolution
    # Test creating a new instance directly with random email to avoid conflicts
    admin = Users::Administrator.create!(
      email: "test-admin-#{Time.now.to_i}@example.com",
      first_name: 'Test',
      last_name: 'Admin',
      password: 'password123',
      password_confirmation: 'password123'
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
      first_name: 'Test',
      last_name: 'Constituent',
      password: 'password123',
      password_confirmation: 'password123'
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

  def test_namespaced_sti_type_storage_and_retrieval
    # Create and save a user with a namespaced type using FactoryBot
    user = create(:user, type: 'Users::Administrator')
    user_id = user.id

    # Explicitly reload from DB to ensure we test what's actually stored
    reloaded_user = User.find(user_id)

    # Verify correct type string is stored
    assert_equal 'Users::Administrator', reloaded_user.type

    # Verify object is the right class (true STI behavior)
    assert_instance_of Users::Administrator, reloaded_user

    # Clean up
    user.destroy
  end

  def test_vendor_to_evaluator_transition_without_validation_crossover
    # Create a valid Vendor with all required fields and ensure unique email
    unique_email = "vendor-to-evaluator-test-#{Time.now.to_i}@example.com"
    vendor = create(:vendor_user, email: unique_email)
    assert vendor.valid?, "Starting vendor should be valid: #{vendor.errors.full_messages.join(', ')}"

    # Change type to Evaluator
    vendor.type = 'Users::Evaluator'

    # Core of the test: Should save successfully without Vendor validations firing
    assert vendor.save, "Failed to change type: #{vendor.errors.full_messages.join(', ')}"

    # Verify the type was actually changed
    # Use User.find rather than vendor.reload as the type has changed
    # and the object is no longer a Users::Vendor
    reloaded_user = User.find(vendor.id)
    assert_equal 'Users::Evaluator', reloaded_user.type
    assert_instance_of Users::Evaluator, reloaded_user # Check the reloaded user's class

    # Clean up
    vendor.destroy
  end
end
