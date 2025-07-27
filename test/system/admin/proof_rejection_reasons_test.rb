# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class ProofRejectionReasonsTest < ApplicationSystemTestCase
    setup do
      setup_fpl_policies
      
      @admin = create(:admin)
      @user = create(:constituent, hearing_disability: true)
      @application = create(:application, :old_enough_for_new_application, user: @user)
      @application.update!(status: 'needs_information')

      # Attach proofs using the lightweight helper
      attach_lightweight_proof(@application, :income_proof)
      attach_lightweight_proof(@application, :residency_proof)

      # Ensure proof statuses are set correctly for button text to be "Review Proof"
      @application.update!(
        income_proof_status: :not_reviewed,
        residency_proof_status: :not_reviewed
      )

      # Clean up any existing proof reviews for this application to avoid interference
      @application.proof_reviews.destroy_all

      sign_in(@admin)
    end

    test 'admin can see all rejection reasons when rejecting income proof' do
      visit admin_application_path(@application)
      wait_for_turbo
      wait_for_page_stable

      # Wait for page to be fully loaded using Capybara's native waiting
      # Use a more defensive approach to handle potential browser corruption
      begin
        assert_text(/Application Details|Application #/i, wait: 15)
      rescue Ferrum::NodeNotFoundError => e
        puts "Browser corruption detected during assert_text, restarting browser..."
        if respond_to?(:force_browser_restart, true)
          force_browser_restart('assert_text_recovery')
        else
          Capybara.reset_sessions!
        end
        # Re-visit the page and try again
        visit admin_application_path(@application)
        wait_for_page_stable
        assert_text(/Application Details|Application #/i, wait: 15)
      end
      assert_selector '#attachments-section', wait: 10

      # Use stable element finding with Capybara's native waiting
      assert_selector('button[data-modal-id="incomeProofReviewModal"]', wait: 15)
      find('button[data-modal-id="incomeProofReviewModal"]').click

      wait_for_modal_open('incomeProofReviewModal', timeout: 15)

      within_modal('#incomeProofReviewModal') do
        assert_selector('button', text: 'Reject', wait: 3)
        click_button 'Reject'
      end

      # Wait for the rejection modal to open and be fully initialized
      wait_for_modal_open('proofRejectionModal', timeout: 15)

      # Wait for Stimulus controllers to initialize properly
      wait_for_stimulus_controller('rejection-form', timeout: 10)

      within_modal('#proofRejectionModal') do
        # Wait for proof type field and verify it's set correctly
        assert_selector('#rejection-proof-type', visible: false, wait: 5)

        # Use a more reliable way to get the proof type value
        proof_type_field = page.find_by_id('rejection-proof-type', visible: false, wait: 5)
        proof_type_value = proof_type_field.value
        assert_equal 'income', proof_type_value

        # Check that all common rejection reason buttons are visible
        assert_selector "button[data-reason-type='addressMismatch']", text: 'Address Mismatch', wait: 5
        assert_selector "button[data-reason-type='expired']", text: 'Expired Documentation', wait: 5
        assert_selector "button[data-reason-type='missingName']", text: 'Missing Name', wait: 5
        assert_selector "button[data-reason-type='wrongDocument']", text: 'Wrong Document Type', wait: 5

        # Wait for income-specific buttons to become visible after Stimulus updates
        assert_selector "button[data-reason-type='missingAmount']", text: 'Missing Amount', wait: 10
        assert_selector "button[data-reason-type='exceedsThreshold']", text: 'Income Exceeds Threshold', wait: 5
        assert_selector "button[data-reason-type='outdatedSsAward']", text: 'Outdated SS Award Letter', wait: 5
      end
    rescue Minitest::Assertion => e
      take_screenshot('rejection_reasons_income_proof_failure')
      raise e
    end

    test 'admin can see appropriate rejection reasons when rejecting residency proof' do
      visit admin_application_path(@application)
      wait_for_turbo
      wait_for_page_stable
      
      # Look for the specific heading text expected by the page with defensive error handling
      begin
        assert_text(/Application #\d+ Details/i, wait: 15)
      rescue Ferrum::NodeNotFoundError => e
        puts "Browser corruption detected during assert_text, restarting browser..."
        if respond_to?(:force_browser_restart, true)
          force_browser_restart('assert_text_recovery')
        else
          Capybara.reset_sessions!
        end
        # Re-visit the page and try again
        visit admin_application_path(@application)
        wait_for_page_stable
        assert_text(/Application #\d+ Details/i, wait: 15)
      end
      assert_selector('#attachments-section', wait: 15)

      # Use stable element finding with Capybara's native waiting
      assert_selector('button[data-modal-id="residencyProofReviewModal"]', wait: 15)
      find('button[data-modal-id="residencyProofReviewModal"]').click
      wait_for_modal_open('residencyProofReviewModal', timeout: 15)

      within_modal('#residencyProofReviewModal') do
        assert_selector('button', text: 'Reject', wait: 3)
        click_button 'Reject'
      end

      # Wait for the rejection modal to open and be fully initialized
      wait_for_modal_open('proofRejectionModal', timeout: 15)

      # Wait for the modal to be fully initialized before checking proof type
      within_modal('#proofRejectionModal') do
        assert_selector('#rejection-proof-type', visible: false, wait: 3)
        proof_type_value = find_by_id('rejection-proof-type', visible: false).value
        assert_equal 'residency', proof_type_value
      end

      # Check that common rejection reason buttons are visible
      within_modal('#proofRejectionModal') do
        assert_selector "button[data-reason-type='addressMismatch']", text: 'Address Mismatch'
        assert_selector "button[data-reason-type='expired']", text: 'Expired Documentation'
        assert_selector "button[data-reason-type='missingName']", text: 'Missing Name'
        assert_selector "button[data-reason-type='wrongDocument']", text: 'Wrong Document Type'

        # Check that income-specific rejection reason buttons are hidden
        assert_selector "button[data-reason-type='missingAmount']", visible: false
        assert_selector "button[data-reason-type='exceedsThreshold']", visible: false
        assert_selector "button[data-reason-type='outdatedSsAward']", visible: false
      end
    rescue Minitest::Assertion => e
      take_screenshot('rejection_reasons_residency_proof_failure')
      raise e
    end

    test 'clicking a rejection reason button populates the reason field' do
      visit admin_application_path(@application)
      wait_for_turbo

      # Use stable element finding with Capybara's native waiting
      assert_selector('button[data-modal-id="incomeProofReviewModal"]', wait: 15)
      find('button[data-modal-id="incomeProofReviewModal"]').click
      wait_for_modal_open('incomeProofReviewModal', timeout: 15)

      within_modal('#incomeProofReviewModal') do
        click_button 'Reject'
      end

      # Wait for the rejection modal to open and be fully initialized
      wait_for_modal_open('proofRejectionModal', timeout: 15)
      wait_for_stimulus_controller('rejection-form', timeout: 10)

      within_modal('#proofRejectionModal') do
        # Wait for the missing name button to be available
        missing_name_button = find("button[data-reason-type='missingName']", wait: 10)
        missing_name_button.click

        # Wait for Stimulus to update the textarea after button click
        assert_selector("textarea[name='rejection_reason']", wait: 5)

        # Wait for the value to be populated (use a more specific check)
        using_wait_time(10) do
          reason_field = page.find("textarea[name='rejection_reason']")
          # Wait until the field has content
          assert reason_field.value.present?, 'Rejection reason field should be populated'
          assert_includes reason_field.value, 'does not show your name'
        end
      end
    rescue Minitest::Assertion => e
      take_screenshot('rejection_reason_populate_failure')
      raise e
    end

    test 'admin can modify the rejection reason text' do
      visit admin_application_path(@application)
      wait_for_turbo
      wait_for_page_stable
      
      # Use Capybara's native waiting for page load with defensive error handling
      begin
        assert_text(/Application Details|Application #/i, wait: 15)
      rescue Ferrum::NodeNotFoundError => e
        puts "Browser corruption detected during assert_text, restarting browser..."
        if respond_to?(:force_browser_restart, true)
          force_browser_restart('assert_text_recovery')
        else
          Capybara.reset_sessions!
        end
        # Re-visit the page and try again
        visit admin_application_path(@application)
        wait_for_page_stable
        assert_text(/Application Details|Application #/i, wait: 15)
      end
      assert_selector('#attachments-section', wait: 10)

      # Use stable element finding with Capybara's native waiting
      assert_selector('button[data-modal-id="incomeProofReviewModal"]', wait: 15)
      find('button[data-modal-id="incomeProofReviewModal"]').click
      wait_for_modal_open('incomeProofReviewModal', timeout: 15)

      within_modal('#incomeProofReviewModal') do
        click_button 'Reject'
      end

      # Wait for the rejection modal to open and be fully initialized
      wait_for_modal_open('proofRejectionModal', timeout: 15)
      wait_for_stimulus_controller('rejection-form', timeout: 10)

      within_modal('#proofRejectionModal') do
        # Click a rejection reason button and wait for population
        missing_name_button = find("button[data-reason-type='missingName']", wait: 10)
        missing_name_button.click

        # Wait for the textarea to be populated after button click
        assert_selector("textarea[name='rejection_reason']", wait: 5)

        # Wait for the value to be populated first
        using_wait_time(10) do
          reason_field = page.find("textarea[name='rejection_reason']")
          assert reason_field.value.present?, 'Field should be populated before modification'
        end

        # Clear and modify the reason text
        custom_message = 'Please provide a document with your full legal name clearly visible.'
        
        # Use a single find call with proper waiting to avoid stale node references
        using_wait_time(10) do
          reason_field = page.find("textarea[name='rejection_reason']", wait: 5)
          reason_field.set(custom_message)
          
          # Verify the custom message was set correctly using the same element reference
          assert_equal custom_message, reason_field.value
        end
      end
    rescue Minitest::Assertion => e
      take_screenshot('rejection_reason_modify_failure')
      raise e
    end
  end
end
