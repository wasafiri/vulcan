# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class ApplicationCreationAuditTest < ApplicationSystemTestCase
    include ActiveStorageHelper

    setup do
      @admin = users(:admin_david)
      @constituent = users(:constituent_alice)
      setup_active_storage_test
      sign_in(@admin)
    end

    teardown do
      clear_active_storage
    end

    test 'admin can see application creation event for online applications' do
      # First create an application as a constituent
      sign_out
      sign_in(@constituent)

      visit new_constituent_portal_application_path

      # Fill in minimum required fields
      fill_in 'Household Size', with: '2'
      fill_in 'Annual income', with: '30000'
      check 'Maryland resident'
      check 'Self-certify disability'

      # Fill in medical provider info
      fill_in 'Medical provider name', with: 'Dr. Smith'
      fill_in 'Medical provider email', with: 'smith@example.com'
      fill_in 'Medical provider phone', with: '555-123-4567'

      # Submit the form
      click_button 'Save Application'

      # Verify application was created
      assert_text 'Application saved as draft'

      # Sign out and sign in as admin
      sign_out
      sign_in(@admin)

      # Find and view the application
      visit admin_applications_path

      # Find application with constituent name
      first('a', text: @constituent.full_name).click

      # Verify the audit log shows the application creation
      within '#audit-logs' do
        assert_text 'Application Created (Online)'
        assert_text 'Application created via Online method'
      end
    end

    test 'admin can see application creation event for paper applications' do
      # Create a paper application
      visit new_admin_paper_application_path

      # Fill in constituent info
      within '#self-info-section' do
        fill_in 'First Name', with: 'John'
        fill_in 'Last name', with: 'Paper'
        fill_in 'Email', with: 'john.paper@example.com'
        fill_in 'Phone', with: '555-987-6543'
        check 'Hearing disability'
      end

      # Fill in application info (these fields are in the main form)
      fill_in 'Household size', with: '3'
      fill_in 'Annual income', with: '45000'
      check 'Maryland resident'
      check 'Self-certify disability'

      # Fill in medical provider info
      fill_in 'Name', with: 'Dr. Jones'
      fill_in 'Email', with: 'jones@example.com'
      fill_in 'Phone', with: '555-333-4444'

      # Submit the form
      click_button 'Submit Paper Application'

      # Verify application was created
      assert_text 'Paper application successfully submitted'

      # Verify the audit log shows the application creation
      within '#audit-logs' do
        assert_text 'Application Created (Paper)'
        assert_text 'Application created via Paper method'
      end
    end
  end
end
