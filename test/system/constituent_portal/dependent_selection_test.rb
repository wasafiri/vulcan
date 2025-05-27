# frozen_string_literal: true

require 'application_system_test_case'
require_relative '../../support/cuprite_test_bridge'

module ConstituentPortal
  class DependentSelectionTest < ApplicationSystemTestCase
    include CupriteTestBridge

    setup do
      # Create a guardian (current user) with multiple dependents
      # Using unique phone numbers that match the 10-digit US format
      Time.current.to_i
      @guardian = create(:constituent, email: 'guardian.test@example.com', phone: "555-123-#{rand(1000..9999)}")

      # Create two dependents with different names
      @dependent1 = create(:constituent, first_name: 'First', last_name: 'Dependent', email: 'dep1@example.com',
                                         phone: "555-234-#{rand(1000..9999)}")
      @dependent2 = create(:constituent, first_name: 'Second', last_name: 'Dependent', email: 'dep2@example.com',
                                         phone: "555-345-#{rand(1000..9999)}")

      # Create guardian relationships
      create(:guardian_relationship,
             guardian_user: @guardian,
             dependent_user: @dependent1,
             relationship_type: 'Parent')

      create(:guardian_relationship,
             guardian_user: @guardian,
             dependent_user: @dependent2,
             relationship_type: 'Legal Guardian')

      # Sign in as the guardian
      enhanced_sign_in(@guardian)

      # After sign-in, we need to explicitly visit the dashboard
      safe_visit constituent_portal_dashboard_path
      wait_for_page_load

      # Verify we're on the dashboard page
      assert_text 'My Dashboard', wait: 10
    end

    teardown do
      enhanced_sign_out if defined?(page) && page.driver.respond_to?(:browser)
    end

    test 'clicking Start Application from dashboard shows correct dependent name in title' do
      # Visit the dashboard page
      safe_visit constituent_portal_dashboard_path
      wait_for_page_load

      # Ensure the dependents section is visible
      assert_selector 'h4', text: 'My Dependents', wait: 5, visible: :all

      # Find the row for the first dependent
      within('li', text: @dependent1.full_name, visible: :all) do
        # Click the "Start Application" button for the first dependent
        click_on 'Start Application', visible: :all
      end

      # Wait for the application form to load
      wait_for_page_load

      # Verify the page title includes the dependent's name
      assert_selector 'h1#form-title', text: "New Application for #{@dependent1.full_name}", wait: 5, visible: :all

      # Verify the correct radio button is selected
      assert_checked_field 'A dependent I manage', visible: :all

      # Verify the dependent dropdown is visible and has the correct dependent selected
      assert_selector '#dependent-selection-fields', visible: :all

      # Look for the dependent dropdown with the correct selection
      within('#dependent-selection-fields', visible: :all) do
        assert_selector 'select[data-dependent-selector-target="dependentSelect"]', visible: :all
        assert_selector "option[selected][value='#{@dependent1.id}']", visible: :all
      end
    end

    test 'toggling between Myself and A dependent I manage radio buttons updates title correctly' do
      # Visit the new application page
      safe_visit new_constituent_portal_application_path
      wait_for_page_load

      # By default, "Myself" should be selected and title should be "New Application"
      assert_checked_field 'Myself', visible: :all
      assert_selector 'h1#form-title', text: 'New Application', wait: 5, visible: :all

      # Select "A dependent I manage" radio button
      choose 'A dependent I manage', visible: :all
      sleep 1 # Wait for UI update

      # Dependent selection should become visible
      assert_selector '#dependent-selection-fields', visible: :all

      # Select the first dependent from the dropdown
      select @dependent1.full_name, from: 'Select Dependent', visible: :all
      sleep 1 # Wait for UI update

      # Wait for JavaScript to execute and update the title
      assert_selector 'h1#form-title', text: "New Application for #{@dependent1.full_name}", wait: 6, visible: :all

      # Switch back to "Myself"
      choose 'Myself', visible: :all
      sleep 1 # Increased sleep

      # Title should change back to "New Application"
      assert_selector 'h1#form-title', text: 'New Application', wait: 5, visible: :all

      # Dependent selection should be hidden
      assert_selector '#dependent-selection-fields', visible: false, wait: 5
    end

    test 'selecting different dependents from dropdown updates title correctly' do
      # Visit the new application page
      safe_visit new_constituent_portal_application_path
      wait_for_page_load

      # Select "A dependent I manage" radio button
      choose 'A dependent I manage', visible: :all
      sleep 1 # Increased sleep

      # Verify dependent selection is visible
      assert_selector '#dependent-selection-fields', visible: :all

      # Select the first dependent
      select @dependent1.full_name, from: 'Select Dependent', visible: :all
      sleep 1 # Increased sleep

      # Verify title updates to first dependent's name
      assert_selector 'h1#form-title', text: "New Application for #{@dependent1.full_name}", wait: 5, visible: :all

      # Change to the second dependent
      select @dependent2.full_name, from: 'Select Dependent', visible: :all
      sleep 1 # Increased sleep

      # Verify title updates to second dependent's name
      assert_selector 'h1#form-title', text: "New Application for #{@dependent2.full_name}", wait: 5, visible: :all
    end

    test 'handles application form with url parameter for dependent' do
      # Visit the new application page with user_id parameter for dependent1
      safe_visit new_constituent_portal_application_path(user_id: @dependent1.id)
      wait_for_page_load

      # Verify "A dependent I manage" is selected automatically
      assert_checked_field 'A dependent I manage', visible: :all
      sleep 1 # Increased sleep

      # Verify the dependent dropdown is visible and shows the correct dependent
      assert_selector '#dependent-selection-fields', visible: :all

      # Look for the dependent dropdown with the correct selection
      within('#dependent-selection-fields', visible: :all) do
        assert_selector 'select[data-dependent-selector-target="dependentSelect"]', visible: :all
        assert_selector "option[selected][value='#{@dependent1.id}']", visible: :all
      end

      # Verify title includes the dependent's name
      assert_selector 'h1#form-title', text: "New Application for #{@dependent1.full_name}", wait: 5, visible: :all
    end

    test 'handles application form with for_self=false parameter' do
      # Visit the new application page with for_self=false parameter
      safe_visit new_constituent_portal_application_path(for_self: false)
      wait_for_page_load

      # Verify "A dependent I manage" is selected automatically
      assert_checked_field 'A dependent I manage', visible: :all
      sleep 1 # Increased sleep

      # Verify the dependent dropdown is visible
      assert_selector '#dependent-selection-fields', visible: :all

      # Verify the dropdown exists but no dependent is selected yet
      within('#dependent-selection-fields', visible: :all) do
        assert_selector 'select[data-dependent-selector-target="dependentSelect"]', visible: :all
        assert_no_selector "option[selected][value='#{@dependent1.id}']", visible: :all
        assert_no_selector "option[selected][value='#{@dependent2.id}']", visible: :all
      end

      # Title should still be "New Application" until a dependent is selected
      assert_selector 'h1#form-title', text: 'New Application', wait: 5, visible: :all

      # Select a dependent
      select @dependent2.full_name, from: 'Select Dependent', visible: :all
      sleep 1 # Increased sleep

      # Title should update to include the dependent's name
      assert_selector 'h1#form-title', text: "New Application for #{@dependent2.full_name}", wait: 5, visible: :all
    end
  end
end
