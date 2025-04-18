# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class PaperApplicationRejectionTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin)
      sign_in(@admin)
    end

    test 'admin can see all rejection reasons for income proof' do
      visit new_admin_paper_application_path

      # Select reject income proof
      find('#reject_income_proof').click

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

      # Select reject residency proof
      find('#reject_residency_proof').click

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

      # Select reject income proof
      find('#reject_income_proof').click

      # Select a rejection reason
      select 'Missing Name', from: 'income_proof_rejection_reason'

      # Check that the notes field is populated
      notes_field = find("[name='income_proof_rejection_notes']")
      assert_not_empty notes_field.value
      assert_includes notes_field.value, 'does not show your name'
    end

    test 'admin can modify the rejection notes' do
      visit new_admin_paper_application_path

      # Select reject income proof
      find('#reject_income_proof').click

      # Select a rejection reason
      select 'Missing Name', from: 'income_proof_rejection_reason'

      # Modify the notes
      custom_message = 'Please provide a document with your full legal name clearly visible.'
      fill_in 'income_proof_rejection_notes', with: custom_message

      # Check that the notes field contains the custom message
      notes_field = find("[name='income_proof_rejection_notes']")
      assert_equal custom_message, notes_field.value
    end
  end
end
