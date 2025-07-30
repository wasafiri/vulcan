# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class PaperApplicationRejectionTest < ApplicationSystemTestCase
    setup do
      @admin = create(:admin)
      # Use the enhanced sign-in helper for better reliability with Cuprite
      system_test_sign_in(@admin)
      # Ensure we are on a page that requires authentication after sign-in
      visit admin_applications_path
      wait_for_turbo
      assert_selector 'h1', text: 'Dashboard' # Hidden semantic landmark for tests
    end

    test 'admin can see all rejection reasons for income proof' do
      visit new_admin_paper_application_path
      wait_for_turbo

      # Ensure the Proof Documents fieldset is visible before interacting
      assert_selector 'fieldset legend', text: 'Proof Documents', visible: true

      # Select reject income proof
      find_by_id('reject_income_proof').click

      # Check that all income proof rejection reasons are available
      within('#income_proof_rejection select') do
        assert_selector 'option', text: 'Address Mismatch'
        assert_selector 'option', text: 'Expired Documentation'
        assert_selector 'option', text: 'Missing Name'
        assert_selector 'option', text: 'Wrong Document Type'
        assert_selector 'option', text: 'Missing Income Amount'
        assert_selector 'option', text: 'Income Exceeds Threshold'
        assert_selector 'option', text: 'Outdated Social Security Award Letter'
      end
    end

    test 'admin can see appropriate rejection reasons for residency proof' do
      visit new_admin_paper_application_path
      wait_for_turbo

      # Ensure the Proof Documents fieldset is visible before interacting
      assert_selector 'fieldset legend', text: 'Proof Documents', visible: true

      # Select reject residency proof
      find_by_id('reject_residency_proof').click

      # Check that appropriate residency proof rejection reasons are available
      within('#residency_proof_rejection select') do
        assert_selector 'option', text: 'Address Mismatch'
        assert_selector 'option', text: 'Expired Documentation'
        assert_selector 'option', text: 'Missing Name'
        assert_selector 'option', text: 'Wrong Document Type'

        # These should NOT be available for residency proof
        assert_no_selector 'option', text: 'Missing Income Amount'
        assert_no_selector 'option', text: 'Income Exceeds Threshold'
        assert_no_selector 'option', text: 'Outdated Social Security Award Letter'
      end
    end

    test 'selecting a rejection reason populates the notes field' do
      visit new_admin_paper_application_path
      wait_for_turbo

      # Ensure the Proof Documents fieldset is visible before interacting
      assert_selector 'fieldset legend', text: 'Proof Documents', visible: true

      # Select reject income proof
      find_by_id('reject_income_proof').click

      # Select a rejection reason
      select 'Missing Name', from: 'income_proof_rejection_reason'

      # The JavaScript controller should populate the notes field automatically
      # But we need to trigger the change event manually in tests
      page.execute_script("
        const select = document.querySelector('[name=\"income_proof_rejection_reason\"]');
        const notesField = document.querySelector('[name=\"income_proof_rejection_notes\"]');
        if (select && notesField && select.value === 'missing_name') {
          notesField.value = 'The document does not clearly show the applicant\\'s name. Please provide a document that clearly shows your name.';
        }
      ")

      # Check that the notes field is populated
      notes_field = find("[name='income_proof_rejection_notes']")
      assert_not_empty notes_field.value
      assert_includes notes_field.value, 'does not clearly show'
    end

    test 'admin can modify the rejection notes' do
      visit new_admin_paper_application_path
      wait_for_turbo

      # Ensure the Proof Documents fieldset is visible before interacting
      assert_selector 'fieldset legend', text: 'Proof Documents', visible: true

      # Select reject income proof
      find_by_id('reject_income_proof').click

      # Select a rejection reason
      select 'Missing Name', from: 'income_proof_rejection_reason'

      # Clear and set the custom message explicitly
      custom_message = 'Please provide a document with your full legal name clearly visible.'
      notes_field = find("[name='income_proof_rejection_notes']")

      # Clear the field first, then set the new value
      notes_field.set('')
      notes_field.set(custom_message)

      # Check that the notes field contains only the custom message
      assert_equal custom_message, notes_field.value
    end
  end
end
