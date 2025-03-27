# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class PaperApplicationsTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_david)
      sign_in @admin
    end

    test 'admin can access paper application form' do
      visit admin_applications_path

      assert_selector 'h1', text: 'Applications'
      assert_link 'Upload Paper Application'

      click_on 'Upload Paper Application'

      assert_selector 'h1', text: 'Upload Paper Application'
      assert_selector 'fieldset legend', text: 'Constituent Information'
      assert_selector 'fieldset legend', text: 'Application Details'
      assert_selector 'fieldset legend', text: 'Disability Information'
      assert_selector 'fieldset legend', text: 'Medical Provider Information'
      assert_selector 'fieldset legend', text: 'Proof Documents'
    end

    test 'checkboxes are not checked by default' do
      visit new_admin_paper_application_path

      # Verify that none of the checkboxes are checked by default
      within 'fieldset', text: 'Application Details' do
        assert_not find('#application_maryland_resident').checked?
        assert_not find('#application_self_certify_disability').checked?
        assert_not find('#application_terms_accepted').checked?
        assert_not find('#application_information_verified').checked?
        assert_not find('#application_medical_release_authorized').checked?
      end

      # Verify that disability checkboxes are not checked by default
      within 'fieldset', text: 'Disability Information' do
        assert_not find('#constituent_hearing_disability').checked?
        assert_not find('#constituent_vision_disability').checked?
        assert_not find('#constituent_speech_disability').checked?
        assert_not find('#constituent_mobility_disability').checked?
        assert_not find('#constituent_cognition_disability').checked?
        assert_not find('#constituent_is_guardian').checked?
      end
    end

    test 'admin can submit a paper application with valid data' do
      # Ensure we have the FPL policies set up
      Policy.find_or_create_by(key: 'fpl_2_person').update(value: 20_000)
      Policy.find_or_create_by(key: 'fpl_modifier_percentage').update(value: 400)

      visit new_admin_paper_application_path

      # Fill in constituent information with a unique email
      within 'fieldset', text: 'Constituent Information' do
        fill_in 'First Name', with: 'John'
        fill_in 'Last Name', with: 'Doe'
        # Use a unique email to avoid conflicts with existing applications
        fill_in 'Email', with: "john.doe.#{Time.now.to_i}@example.com"
        fill_in 'Phone', with: '555-123-4567'
        fill_in 'Address Line 1', with: '123 Main St'
        fill_in 'City', with: 'Baltimore'
        fill_in 'ZIP Code', with: '21201'
      end

      # Fill in application details with income below threshold
      within 'fieldset', text: 'Application Details' do
        fill_in 'Household Size', with: '2'
        fill_in 'Annual Income', with: '10000' # 10k < 400% of 20k
      end

      # Move focus to trigger validation
      find('body').click

      # Verify submit button is enabled
      assert_no_selector 'input[type=submit][disabled]'

      within 'fieldset', text: 'Application Details' do
        check 'I certify that the applicant is a resident of Maryland'
        check 'The applicant certifies that they have a disability that affects their ability to access telecommunications services'
        check 'The applicant has accepted the terms and conditions'
        check 'The applicant has verified that all information is correct'
        check 'The applicant has authorized the release of medical information'
      end

      # Select disability information
      within 'fieldset', text: 'Disability Information' do
        check 'Hearing'
      end

      # Fill in medical provider information
      within 'fieldset', text: 'Medical Provider Information' do
        fill_in 'Name', with: 'Dr. Jane Smith'
        fill_in 'Phone', with: '555-987-6543'
        fill_in 'Email', with: 'dr.smith@example.com'
      end

      # Handle proof documents
      within 'fieldset', text: 'Proof Documents' do
        # Income proof
        find("input[id='accept_income_proof']").click
        attach_file 'income_proof', Rails.root.join('test/fixtures/files/sample.pdf'), visible: false

        # Residency proof
        find("input[id='accept_residency_proof']").click
        attach_file 'residency_proof', Rails.root.join('test/fixtures/files/sample.pdf'), visible: false
      end

      click_on 'Submit Paper Application'

      assert_text 'Paper application successfully submitted'
      assert_current_path %r{/admin/applications/\d+}
    end

    test 'admin can see income threshold warning when income exceeds threshold' do
      # Ensure we have the FPL policies set up
      Policy.find_or_create_by(key: 'fpl_2_person').update(value: 20_000)
      Policy.find_or_create_by(key: 'fpl_modifier_percentage').update(value: 400)

      visit new_admin_paper_application_path

      # Fill in household size and income that exceeds threshold
      fill_in 'Household Size', with: '2'
      fill_in 'Annual Income', with: '100000' # 100k > 400% of 20k

      # Move focus to trigger validation
      find('body').click

      # Warning should be visible
      assert_selector '#income-threshold-warning', visible: true
      assert_text 'Income Exceeds Threshold'

      # Badge should be visible in the Proof Documents section
      within 'fieldset', text: 'Proof Documents' do
        assert_selector '#income-threshold-badge', visible: true
        assert_text 'Exceeds Income Threshold'
        assert_text 'This application cannot be submitted because the income exceeds the maximum threshold.'
      end

      # Submit button should be disabled
      assert_selector 'input[type=submit][disabled]'

      # Rejection button should be visible
      assert_selector '#rejection-button', visible: true
    end

    test 'income threshold badge disappears when income is reduced below threshold' do
      # Ensure we have the FPL policies set up
      Policy.find_or_create_by(key: 'fpl_2_person').update(value: 20_000)
      Policy.find_or_create_by(key: 'fpl_modifier_percentage').update(value: 400)

      visit new_admin_paper_application_path

      # Fill in household size and income that exceeds threshold
      fill_in 'Household Size', with: '2'
      fill_in 'Annual Income', with: '100000' # 100k > 400% of 20k

      # Move focus to trigger validation
      find('body').click

      # Badge should be visible in the Proof Documents section
      within 'fieldset', text: 'Proof Documents' do
        assert_selector '#income-threshold-badge', visible: true
      end

      # Now reduce income below threshold
      fill_in 'Annual Income', with: '50000' # 50k < 400% of 20k

      # Move focus to trigger validation
      find('body').click

      # Badge should no longer be visible
      within 'fieldset', text: 'Proof Documents' do
        assert_no_selector '#income-threshold-badge', visible: true
      end

      # Submit button should be enabled
      assert_no_selector 'input[type=submit][disabled]'
    end

    test 'admin can see rejection button for application exceeding income threshold' do
      # Ensure we have the FPL policies set up
      Policy.find_or_create_by(key: 'fpl_2_person').update(value: 20_000)
      Policy.find_or_create_by(key: 'fpl_modifier_percentage').update(value: 400)

      visit new_admin_paper_application_path

      # Fill in constituent information with a unique email
      within 'fieldset', text: 'Constituent Information' do
        fill_in 'First Name', with: 'John'
        fill_in 'Last Name', with: 'Doe'
        # Use a unique email to avoid conflicts with existing applications
        fill_in 'Email', with: "john.doe.#{Time.now.to_i}@example.com"
        fill_in 'Phone', with: '555-123-4567'
      end

      # Fill in household size and income that exceeds threshold
      fill_in 'Household Size', with: '2'
      fill_in 'Annual Income', with: '100000' # 100k > 400% of 20k

      # Move focus to trigger validation
      find('body').click

      # Verify rejection button is visible
      assert_selector '#rejection-button', visible: true

      # Verify submit button is disabled
      assert_selector 'input[type=submit][disabled]'
    end

    test 'admin can submit application with rejected proofs' do
      # Ensure we have the FPL policies set up
      Policy.find_or_create_by(key: 'fpl_2_person').update(value: 20_000)
      Policy.find_or_create_by(key: 'fpl_modifier_percentage').update(value: 400)

      visit new_admin_paper_application_path

      # Fill in constituent information with a unique email
      within 'fieldset', text: 'Constituent Information' do
        fill_in 'First Name', with: 'John'
        fill_in 'Last Name', with: 'Doe'
        # Use a unique email to avoid conflicts
        fill_in 'Email', with: "john.doe.rejected.#{Time.now.to_i}@example.com"
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

      # Handle proof documents - both rejected
      within 'fieldset', text: 'Proof Documents' do
        # Income proof
        find("input[id='reject_income_proof']").click
        select 'Missing Income Amount', from: 'income_proof_rejection_reason'
        # Notes should be auto-filled by JavaScript

        # Residency proof
        find("input[id='reject_residency_proof']").click
        select 'Expired Documentation', from: 'residency_proof_rejection_reason'
        # Notes should be auto-filled by JavaScript
      end

      click_on 'Submit Paper Application'

      # Should be redirected to application page with detailed success message
      assert_text 'Paper application successfully submitted with 2 rejected proofs: income and residency. Notifications will be sent.'
      assert_current_path %r{/admin/applications/\d+}

      # Check statuses are rejected
      assert_text 'Income Proof: Rejected'
      assert_text 'Residency Proof: Rejected'

      # Verify proof reviews
      assert_text 'Missing Income Amount'
      assert_text 'Expired Documentation'
    end

    test 'attachments are preserved when validation fails' do
      visit new_admin_paper_application_path

      # Fill in partial information but attach files
      within 'fieldset', text: 'Constituent Information' do
        fill_in 'First Name', with: 'John'
        fill_in 'Last Name', with: 'Doe'
        # Intentionally skip email to cause validation error
        fill_in 'Phone', with: '555-123-4567'
      end

      # Handle proof documents
      within 'fieldset', text: 'Proof Documents' do
        # Income proof
        find("input[id='accept_income_proof']").click
        attach_file 'income_proof', Rails.root.join('test/fixtures/files/sample.pdf'), visible: false

        # Residency proof
        find("input[id='accept_residency_proof']").click
        attach_file 'residency_proof', Rails.root.join('test/fixtures/files/sample.pdf'), visible: false
      end

      click_on 'Submit Paper Application'

      # Should see validation error, still on form page
      assert_text "Constituent email can't be blank"
      # Check for the file preservation message
      assert_text 'Your uploaded files have been preserved'
      # The path should remain on the paper applications path after form resubmission
      assert_current_path %r{/admin/paper_applications}

      # Now fill in the missing information
      within 'fieldset', text: 'Constituent Information' do
        fill_in 'Email', with: "preserved.files.#{Time.now.to_i}@example.com"
      end

      # Complete required fields
      within 'fieldset', text: 'Application Details' do
        fill_in 'Household Size', with: '2'
        fill_in 'Annual Income', with: '10000'
        check 'I certify that the applicant is a resident of Maryland'
      end

      within 'fieldset', text: 'Disability Information' do
        check 'The applicant certifies that they have a disability that affects their ability to access telecommunications services'
      end

      within 'fieldset', text: 'Medical Provider Information' do
        fill_in 'Name', with: 'Dr. Jane Smith'
        fill_in 'Phone', with: '555-987-6543'
        fill_in 'Email', with: 'dr.smith@example.com'
      end

      # Verify files are still shown on the form
      within 'fieldset', text: 'Proof Documents' do
        # Income proof - should still show accept selected
        assert find("input[id='accept_income_proof']").checked?

        # Residency proof - should still show accept selected
        assert find("input[id='accept_residency_proof']").checked?
      end

      click_on 'Submit Paper Application'

      # Should be redirected to application page
      assert_text 'Paper application successfully submitted'
      assert_current_path %r{/admin/applications/\d+}

      # Check that files were properly attached
      assert_text 'Income Proof: Approved'
      assert_text 'Residency Proof: Approved'
    end
  end
end
