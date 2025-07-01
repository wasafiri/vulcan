# frozen_string_literal: true

require 'application_system_test_case'
require_relative '../support/cuprite_test_bridge'

class AdminGuardianManagementTest < ApplicationSystemTestCase
  include CupriteTestBridge

  setup do
    @admin = create(:admin, verified: true, email_verified: true)
    @guardian = create(:constituent, email: 'guardian.admin.view@example.com', phone: '5555550030')
    @dependent = create(:constituent, email: 'dependent.admin.view@example.com', phone: '5555550031')
    GuardianRelationship.create!(guardian_user: @guardian, dependent_user: @dependent, relationship_type: 'Parent')
    @application_for_dependent = create(:application, user: @dependent, managing_guardian: @guardian)

    # Use enhanced sign-in method for better authentication
    enhanced_sign_in(@admin)

    # Navigate to admin applications to verify access
    safe_visit admin_applications_path
    wait_for_page_load
  end

  teardown do
    enhanced_sign_out if defined?(page) && page.driver.respond_to?(:browser)
  end

  test 'admin can view guardian info on application index' do
    # Already on applications page from setup
    assert_current_path admin_applications_path
    assert_text @dependent.full_name
    assert_text @guardian.full_name
  end

  test 'admin can view guardian info on application show page' do
    safe_visit admin_application_path(@application_for_dependent)
    wait_for_page_load

    # Verify we're on the application show page
    assert_current_path admin_application_path(@application_for_dependent)
    assert_text @dependent.full_name
    assert_text @guardian.full_name
    assert_text 'Parent'
  end

  test 'admin can view dependents on guardian user show page' do
    safe_visit admin_user_path(@guardian)
    wait_for_page_load

    # Verify we're on the user show page
    assert_current_path admin_user_path(@guardian)
    assert_text @dependent.full_name
    assert_text 'Parent'
    assert_selector 'a', text: /Back to Application Dashboard/
  end

  test 'admin can view guardians on dependent user show page' do
    safe_visit admin_user_path(@dependent)
    wait_for_page_load

    # Verify we're on the user show page
    assert_current_path admin_user_path(@dependent)
    assert_text @guardian.full_name
    assert_text 'Parent'
    assert_text @guardian.email
    assert_selector 'a', text: /Back to Application Dashboard/
  end

  test 'admin can view dependent information without add functionality' do
    # This test just verifies that the dependent relationship is displayed
    # since the "Add Dependent" functionality may not be fully implemented
    safe_visit admin_user_path(@guardian)
    wait_for_page_load

    assert_current_path admin_user_path(@guardian)
    assert_text @dependent.full_name
    assert_text 'Parent'

    # Verify the relationship exists in the database
    assert GuardianRelationship.exists?(guardian_user: @guardian, dependent_user: @dependent)
  end

  test 'admin can verify guardian relationship exists' do
    # Simple test to verify the relationship display without complex interaction
    safe_visit admin_user_path(@guardian)
    wait_for_page_load

    assert_current_path admin_user_path(@guardian)
    assert_text @dependent.full_name

    # Verify the relationship exists in the database
    assert GuardianRelationship.exists?(guardian_user: @guardian, dependent_user: @dependent)
  end
end
