# frozen_string_literal: true

require 'application_system_test_case'
require_relative '../../support/cuprite_test_bridge'

module ConstituentPortal
  class ApplicationTypeTest < ApplicationSystemTestCase
    include CupriteTestBridge

    setup do
      @constituent = create(:constituent)
      enhanced_sign_in(@constituent) # Use enhanced sign-in for more reliable authentication

      # Make sure we're starting on the dashboard
      visit constituent_portal_dashboard_path
      assert_current_path constituent_portal_dashboard_path
    end

    test 'application type is displayed correctly on show page' do
      # Visit the new application page
      visit new_constituent_portal_application_path
      wait_for_page_load # Ensure the page is fully loaded before proceeding

      # Fill in required fields
      check 'I certify that I am a resident of Maryland'
      fill_in 'Household Size', with: 3
      fill_in 'Annual Income', with: 45_999

      # Fill in address information
      fill_in 'Street Address', with: '123 Test St'
      fill_in 'City', with: 'Baltimore'
      select 'Maryland', from: 'State'
      fill_in 'Zip Code', with: '21201'

      # Fill in disability information
      check 'I certify that I have a disability that affects my ability to access telecommunications services'
      check 'Hearing'

      # Fill in medical provider info - use the actual fieldset identifier
      within(:xpath, "//section[contains(., 'Medical Provider Information') or contains(., 'Medical Professional Information')]") do
        fill_in 'Name', with: 'Dr. Test Provider'
        fill_in 'Phone', with: '2025551234'
        fill_in 'Email', with: 'test@example.com'
      end

      # Check the medical authorization checkbox
      check 'I authorize the release and sharing of my medical information as described above'

      # Save the application
      click_button 'Save Application'

      # Verify we're redirected to the show page
      assert_text 'Application saved as draft.'

      # Get the application ID from the URL
      current_url =~ %r{/applications/(\d+)}
      application_id = ::Regexp.last_match(1)
      application = Application.find(application_id)

      # Debug the application type
      puts "DEBUG: Application type: #{application.application_type.inspect}"

      # Verify the application type is displayed correctly
      # The application shows the actual value from the database
      assert_text "Application Type: #{application.application_type&.titleize || 'Not specified'}"

      # Update the application type directly in the database
      application.update(application_type: 'new')

      # Refresh the page
      visit current_path

      # Verify the updated application type is displayed
      assert_text 'Application Type: New'

      # Update the application type to renewal
      application.update(application_type: 'renewal')

      # Refresh the page
      visit current_path

      # Verify the updated application type is displayed
      assert_text 'Application Type: Renewal'
    end

    test 'self_certify_disability is set correctly' do
      # Visit the new application page
      visit new_constituent_portal_application_path
      wait_for_page_load # Ensure the page is fully loaded

      # Fill in required fields
      check 'I certify that I am a resident of Maryland'
      fill_in 'Household Size', with: 3
      fill_in 'Annual Income', with: 45_999

      # Fill in address information
      fill_in 'Street Address', with: '123 Test St'
      fill_in 'City', with: 'Baltimore'
      select 'Maryland', from: 'State'
      fill_in 'Zip Code', with: '21201'

      # Use a more reliable method to check the self-certify checkbox
      # Use find + check to ensure we're finding the right element
      within 'section', text: 'Disability Information' do
        # Find the checkbox by its associated label text
        check_box = find('label', text: /I certify that I have a disability/).find(:xpath, '..//input[@type="checkbox"]')
        check_box.check

        # Also check one of the specific disability checkboxes
        find('label', text: 'Hearing').find(:xpath, '..//input[@type="checkbox"]').check
      end

      # Fill in medical provider info - use the actual section identifier
      within(:xpath, "//section[contains(., 'Medical Provider Information') or contains(., 'Medical Professional Information')]") do
        fill_in 'Name', with: 'Dr. Test Provider'
        fill_in 'Phone', with: '2025551234'
        fill_in 'Email', with: 'test@example.com'
      end

      # Check the medical authorization checkbox
      check 'I authorize the release and sharing of my medical information as described above'

      # Take a screenshot to debug if needed

      # Save the application with explicit button identification
      find('input[type="submit"][name="save_draft"]').click

      # Verify we're redirected to the show page
      assert_text 'Application saved as draft.', wait: 5

      # Get the application ID from the URL
      current_url =~ %r{/applications/(\d+)}
      application_id = ::Regexp.last_match(1)
      # Make sure we have a valid application ID
      assert application_id.present?, "Failed to extract application ID from URL: #{current_url}"

      application = Application.find(application_id)

      # Debug the self_certify_disability field
      puts "DEBUG: self_certify_disability: #{application.self_certify_disability.inspect}"
      puts "DEBUG: hearing_disability: #{application.user.hearing_disability.inspect}"

      # Verify the self_certify_disability field is set correctly
      assert application.self_certify_disability, 'self_certify_disability should be true'

      # Verify the self_certify_disability is displayed correctly on the show page
      assert_text 'Self-Certified Disability: Yes'
    end
  end
end
