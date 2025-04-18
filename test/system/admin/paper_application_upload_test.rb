# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class PaperApplicationUploadTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_david)
      sign_in(@admin)

      # Ensure we have the FPL policies set up
      Policy.find_or_create_by(key: 'fpl_2_person').update(value: 20_000)
      Policy.find_or_create_by(key: 'fpl_modifier_percentage').update(value: 400)

      # Set up common test path
      visit new_admin_paper_application_path
    end

    # Fill in minimum required fields for form submission
    def fill_in_minimum_required_fields
      within 'fieldset', text: 'Constituent Information' do
        fill_in 'First Name', with: 'John'
        fill_in 'Last Name', with: 'Doe'
        # Use a unique email to avoid conflicts
        fill_in 'Email', with: "john.doe.#{Time.now.to_i}@example.com"
        fill_in 'Phone', with: '555-123-4567'
        fill_in 'Address Line 1', with: '123 Main St'
        fill_in 'City', with: 'Baltimore'
        fill_in 'ZIP Code', with: '21201'
      end

      # Fill in application details
      within 'fieldset', text: 'Application Details' do
        fill_in 'Household Size', with: '2'
        fill_in 'Annual Income', with: '10000' # Below threshold
        check 'I certify that the applicant is a resident of Maryland'
      end

      # Fill in disability information
      within 'fieldset', text: 'Disability Information' do
        check 'The applicant certifies that they have a disability that affects their ability to access telecommunications services'
        check 'Hearing'
      end

      # Fill in medical provider information
      within 'fieldset', text: 'Medical Provider Information' do
        fill_in 'Name', with: 'Dr. Jane Smith'
        fill_in 'Phone', with: '555-987-6543'
        fill_in 'Email', with: 'dr.smith@example.com'
      end
    end

    test 'switching between accept and reject modes properly manages state' do
      # Test file input disabling when reject is selected
      # First for income proof
      find("input[id='reject_income_proof']").click
      assert find("input[name='income_proof']", visible: false).disabled?,
             'Income proof file input should be disabled when reject is selected'

      # Then for residency proof
      find("input[id='reject_residency_proof']").click
      assert find("input[name='residency_proof']", visible: false).disabled?,
             'Residency proof file input should be disabled when reject is selected'

      # Test file input enabling when accept is selected
      find("input[id='accept_income_proof']").click
      assert_not find_by_id("input[name='income_proof']", visible: false).disabled?,
                 'Income proof file input should be enabled when accept is selected'

      # Test file clearing when switching to reject after uploading
      find("input[id='accept_income_proof']").click

      # Use direct assignment for file input since we're testing the controller behavior not the UI
      attach_file 'income_proof', Rails.root.join('test/fixtures/files/sample.pdf'), visible: false

      # Now switch to reject
      find("input[id='reject_income_proof']").click

      # The file input should be empty now
      file_input = find("input[name='income_proof']", visible: false)
      assert_empty file_input.value, 'File input should be cleared when switching to reject'

      # Check that signed_id hidden field is also cleared
      signed_id_input = find("input[name='income_proof_signed_id']", visible: false)
      assert_empty signed_id_input.value, 'Signed ID field should be cleared when switching to reject'
    end

    test 'form validation prevents submission without required proof decisions' do
      fill_in_minimum_required_fields

      # Try submitting without selecting any option for income proof or residency proof
      click_on 'Submit Paper Application'

      # Should see an error message
      assert_selector '.form-error-container', text: 'Please select an option for income proof'

      # Test accept without file
      find("input[id='accept_income_proof']").click
      find("input[id='accept_residency_proof']").click
      click_on 'Submit Paper Application'

      # Should see an error about missing file
      assert_selector '.form-error-container', text: 'Please upload an income proof document'

      # Test reject without reason
      find("input[id='reject_income_proof']").click
      find("input[id='reject_residency_proof']").click
      click_on 'Submit Paper Application'

      # Should see an error about missing rejection reason
      assert_selector '.form-error-container', text: 'Please select a reason for rejecting income proof'
    end

    test 'full upload flow with valid inputs succeeds' do
      fill_in_minimum_required_fields

      # Handle proof documents properly
      # Income proof accept with file
      find("input[id='accept_income_proof']").click
      attach_file 'income_proof', Rails.root.join('test/fixtures/files/sample.pdf'), visible: false

      # Simulate successful upload by directly setting the signed_id
      # In a real test, we'd need to wait for direct upload to complete
      execute_script("document.querySelector('input[name=\"income_proof_signed_id\"]').value = 'fake-signed-id-for-testing-123';")

      # Residency proof accept with file
      find("input[id='accept_residency_proof']").click
      attach_file 'residency_proof', Rails.root.join('test/fixtures/files/sample.pdf'), visible: false

      # Simulate successful upload by directly setting the signed_id
      execute_script("document.querySelector('input[name=\"residency_proof_signed_id\"]').value = 'fake-signed-id-for-testing-456';")

      # Submit the form
      click_on 'Submit Paper Application'

      # Should be redirected to the application view page
      assert_current_path %r{/admin/applications/\d+}
      assert_text 'Paper application successfully submitted'
    end

    test 'reject flow with valid inputs succeeds' do
      fill_in_minimum_required_fields

      # Handle proof documents - both rejected with reasons
      find("input[id='reject_income_proof']").click
      select 'Missing Income Amount', from: 'income_proof_rejection_reason'
      fill_in 'income_proof_rejection_notes', with: 'Please provide documentation showing income amounts'

      find("input[id='reject_residency_proof']").click
      select 'Expired Documentation', from: 'residency_proof_rejection_reason'
      fill_in 'residency_proof_rejection_notes', with: 'Please provide current documentation'

      # Submit the form
      click_on 'Submit Paper Application'

      # Should be redirected to the application view page
      assert_current_path %r{/admin/applications/\d+}
      assert_text 'Paper application successfully submitted'

      # Check that the proof statuses are set correctly
      assert_text 'Income Proof: Rejected'
      assert_text 'Residency Proof: Rejected'
    end
  end
end
