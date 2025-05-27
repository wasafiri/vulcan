# frozen_string_literal: true

require 'application_system_test_case'
require_relative '../../support/cuprite_test_bridge' # Include CupriteTestBridge for enhanced helpers

module Admin
  class PaperApplicationRejectionTest < ApplicationSystemTestCase
    include CupriteTestBridge # Include the module

    setup do
      @admin = create(:admin)
      # Use the enhanced sign-in helper for better reliability with Cuprite
      enhanced_sign_in(@admin)
      # Ensure we are on a page that requires authentication after sign-in
      safe_visit admin_dashboard_path # Or whatever your admin root path is
      assert_selector 'h1', text: 'Applications' # Assert something on the dashboard
    end

    test 'admin can see all rejection reasons for income proof' do
      safe_visit new_admin_paper_application_path
      wait_for_page_load # Wait for the page and JS to load

      # Ensure the Proof Documents fieldset is visible before interacting
      assert_selector 'fieldset legend', text: 'Proof Documents', visible: true

      # Select reject income proof
      find_by_id('reject_income_proof', wait: 5).click # Add wait for the element

      # Check that all income proof rejection reasons are available
      within('#income_proof_rejection select', wait: 5) do # Add wait for the section
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
      safe_visit new_admin_paper_application_path
      wait_for_page_load # Wait for the page and JS to load

      # Ensure the Proof Documents fieldset is visible before interacting
      assert_selector 'fieldset legend', text: 'Proof Documents', visible: true

      # Select reject residency proof
      find_by_id('reject_residency_proof', wait: 5).click # Add wait for the element

      # Check that appropriate residency proof rejection reasons are available
      within('#residency_proof_rejection select', wait: 5) do # Add wait for the section
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
      safe_visit new_admin_paper_application_path
      wait_for_page_load # Wait for the page and JS to load

      # Ensure the Proof Documents fieldset is visible before interacting
      assert_selector 'fieldset legend', text: 'Proof Documents', visible: true

      # Select reject income proof
      find_by_id('reject_income_proof', wait: 5).click # Add wait

      # Select a rejection reason
      select 'Missing Name', from: 'income_proof_rejection_reason', wait: 5 # Add wait

      # Check that the notes field is populated
      notes_field = find("[name='income_proof_rejection_notes']", wait: 5) # Add wait
      assert_not_empty notes_field.value
      assert_includes notes_field.value, 'does not show your name'
    end

    test 'admin can modify the rejection notes' do
      safe_visit new_admin_paper_application_path
      wait_for_page_load # Wait for the page and JS to load

      # Ensure the Proof Documents fieldset is visible before interacting
      assert_selector 'fieldset legend', text: 'Proof Documents', visible: true

      # Select reject income proof
      find_by_id('reject_income_proof', wait: 5).click # Add wait

      # Select a rejection reason
      select 'Missing Name', from: 'income_proof_rejection_reason', wait: 5 # Add wait

      # Modify the notes
      custom_message = 'Please provide a document with your full legal name clearly visible.'
      fill_in 'income_proof_rejection_notes', with: custom_message, wait: 5 # Add wait

      # Check that the notes field contains the custom message
      notes_field = find("[name='income_proof_rejection_notes']", wait: 5) # Add wait
      assert_equal custom_message, notes_field.value
    end
  end
end
