# frozen_string_literal: true

require 'application_system_test_case'
require_relative '../../support/cuprite_test_bridge'

module Admin
  class PaperApplicationUploadTest < ApplicationSystemTestCase
    include CupriteTestBridge

    setup do
      @admin = create(:admin)
      # Use enhanced sign-in for better reliability with Cuprite
      measure_time('Sign in') { enhanced_sign_in(@admin) }

      # Ensure we have the FPL policies set up
      Policy.find_or_create_by(key: 'fpl_2_person').update(value: 20_000)
      Policy.find_or_create_by(key: 'fpl_modifier_percentage').update(value: 400)

      # Set up common test path
      visit new_admin_paper_application_path
    end

    teardown do
      # Extra cleanup to ensure browser stability
      enhanced_sign_out if defined?(page) && page.driver.respond_to?(:browser)
    end

    # Fill in minimum required fields for form submission
    def fill_in_minimum_required_fields
      within 'fieldset', text: "Applicant's Information" do
        safe_fill_in 'constituent_first_name', with: 'John'
        safe_fill_in 'constituent_last_name', with: 'Doe'
        # Use a unique email to avoid conflicts
        safe_fill_in 'constituent_email', with: "john.doe.#{Time.now.to_i}@example.com"
        safe_fill_in 'constituent_phone', with: '555-123-4567'
        safe_fill_in 'constituent_physical_address_1', with: '123 Main St'
        safe_fill_in 'constituent_city', with: 'Baltimore'
        safe_fill_in 'constituent_zip_code', with: '21201'
      end

      # Select adult applicant type
      within 'fieldset', text: 'Who is this application for?' do
        choose 'An Adult (applying for themselves)'
      end

      # Fill in application details
      within 'fieldset', text: 'Application Details' do
        safe_fill_in 'application_household_size', with: '2'
        safe_fill_in 'application_annual_income', with: '10000' # Below threshold
        check 'application_maryland_resident'
      end

      # Fill in disability information
      within 'fieldset', text: 'Disability Information (for the Applicant)' do
        check 'applicant_attributes_self_certify_disability'
        check 'applicant_attributes_hearing_disability'
      end

      # Fill in medical provider information
      within 'fieldset', text: 'Medical Provider Information' do
        safe_fill_in 'application_medical_provider_name', with: 'Dr. Jane Smith'
        safe_fill_in 'application_medical_provider_phone', with: '555-987-6543'
        safe_fill_in 'application_medical_provider_email', with: 'dr.smith@example.com'
      end
    end

    test 'switching between accept and reject modes properly manages state' do
      # Ensure the radio buttons are visible first
      assert_selector "input[id='accept_income_proof']", visible: :all

      # Test file input disabling when reject is selected
      # First for income proof
      safe_interaction { find("input[id='reject_income_proof']", visible: :all).click }
      assert find("input[name='income_proof']", visible: :all).disabled?,
             'Income proof file input should be disabled when reject is selected'

      # Then for residency proof
      safe_interaction { find("input[id='reject_residency_proof']", visible: :all).click }
      assert find("input[name='residency_proof']", visible: :all).disabled?,
             'Residency proof file input should be disabled when reject is selected'

      # Test file input enabling when accept is selected
      safe_interaction { find("input[id='accept_income_proof']", visible: :all).click }
      assert_not find("input[name='income_proof']", visible: :all).disabled?,
                 'Income proof file input should be enabled when accept is selected'

      # Test file clearing when switching to reject after uploading
      safe_interaction { find("input[id='accept_income_proof']", visible: :all).click }

      # Use direct assignment for file input since we're testing the controller behavior not the UI
      attach_file 'income_proof', Rails.root.join('test/fixtures/files/sample.pdf'), visible: :all

      # Now switch to reject
      safe_interaction { find("input[id='reject_income_proof']", visible: :all).click }

      # The file input should be empty now
      file_input = find("input[name='income_proof']", visible: :all)
      assert_empty file_input.value, 'File input should be cleared when switching to reject'

      # Check that signed_id hidden field is also cleared
      signed_id_input = find("input[name='income_proof_signed_id']", visible: :all)
      assert_empty signed_id_input.value, 'Signed ID field should be cleared when switching to reject'
    end

    test 'form validation prevents submission without required proof decisions' do
      fill_in_minimum_required_fields

      # Try submitting without selecting any option for income proof or residency proof
      safe_interaction { click_on 'Submit Paper Application' }

      # Should see an error message
      assert_selector '.form-error-container', text: 'Please select an option for income proof'

      # Test accept without file
      safe_interaction { find("input[id='accept_income_proof']", visible: :all).click }
      safe_interaction { find("input[id='accept_residency_proof']", visible: :all).click }
      safe_interaction { click_on 'Submit Paper Application' }

      # Should see an error about missing file
      assert_selector '.form-error-container', text: 'Please upload an income proof document'

      # Test reject without reason
      safe_interaction { find("input[id='reject_income_proof']", visible: :all).click }
      safe_interaction { find("input[id='reject_residency_proof']", visible: :all).click }
      safe_interaction { click_on 'Submit Paper Application' }

      # Should see an error about missing rejection reason
      assert_selector '.form-error-container', text: 'Please select a reason for rejecting income proof'
    end

    test 'full upload flow with valid inputs succeeds' do
      fill_in_minimum_required_fields

      # Handle proof documents properly
      # Income proof accept with file
      safe_interaction { find("input[id='accept_income_proof']", visible: :all).click }
      attach_file 'income_proof', Rails.root.join('test/fixtures/files/sample.pdf'), visible: :all

      # Simulate successful upload by directly setting the signed_id
      # In a real test, we'd need to wait for direct upload to complete
      execute_script("document.querySelector('input[name=\"income_proof_signed_id\"]').value = 'fake-signed-id-for-testing-123';")

      # Residency proof accept with file
      safe_interaction { find("input[id='accept_residency_proof']", visible: :all).click }
      attach_file 'residency_proof', Rails.root.join('test/fixtures/files/sample.pdf'), visible: :all

      # Simulate successful upload by directly setting the signed_id
      execute_script("document.querySelector('input[name=\"residency_proof_signed_id\"]').value = 'fake-signed-id-for-testing-456';")

      # Submit the form
      safe_interaction { click_on 'Submit Paper Application' }

      # Should be redirected to the application view page
      assert_current_path %r{/admin/applications/\d+}
      assert_text 'Paper application successfully submitted'
    end

    test 'reject flow with valid inputs succeeds' do
      fill_in_minimum_required_fields

      # Handle proof documents - both rejected with reasons
      safe_interaction { find("input[id='reject_income_proof']", visible: :all).click }
      select 'Missing Income Amount', from: 'income_proof_rejection_reason'
      fill_in 'income_proof_rejection_notes', with: 'Please provide documentation showing income amounts'

      safe_interaction { find("input[id='reject_residency_proof']", visible: :all).click }
      select 'Expired Documentation', from: 'residency_proof_rejection_reason'
      fill_in 'residency_proof_rejection_notes', with: 'Please provide current documentation'

      # Submit the form
      safe_interaction { click_on 'Submit Paper Application' }

      # Should be redirected to the application view page
      assert_current_path %r{/admin/applications/\d+}
      assert_text 'Paper application successfully submitted'

      # Check that the proof statuses are set correctly
      assert_text 'Income Proof: Rejected'
      assert_text 'Residency Proof: Rejected'
    end
  end
end
