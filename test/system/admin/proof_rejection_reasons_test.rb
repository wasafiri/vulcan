# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class ProofRejectionReasonsTest < ApplicationSystemTestCase
    setup do
      # Force a clean browser session for each test
      Capybara.reset_sessions!

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

      # Don't sign in during setup - let each test handle its own authentication
      # This ensures each test starts with a clean authentication state
    end

    teardown do
      # Ensure any open modals are closed
      begin
        if has_selector?('#proofRejectionModal', visible: true, wait: 1)
          within('#proofRejectionModal') do
            click_button 'Cancel' if has_button?('Cancel', wait: 1)
          end
        end

        if has_selector?('#incomeProofReviewModal', visible: true, wait: 1)
          within('#incomeProofReviewModal') do
            click_button 'Close' if has_button?('Close', wait: 1)
          end
        end

        if has_selector?('#residencyProofReviewModal', visible: true, wait: 1)
          within('#residencyProofReviewModal') do
            click_button 'Close' if has_button?('Close', wait: 1)
          end
        end
      rescue Ferrum::NodeNotFoundError, Ferrum::DeadBrowserError
        # Browser might be in a bad state, reset it
        Capybara.reset_sessions!
      end

      # Always ensure clean session state between tests
      Capybara.reset_sessions!
    end

    test 'admin can see all rejection reasons when rejecting income proof' do
      # Always sign in fresh for each test
      system_test_sign_in(@admin)
      visit admin_application_path(@application)

      # Wait for page to load completely with intelligent waiting
      # Use a more specific selector that indicates the page has fully loaded
      assert_selector 'h1#application-title', wait: 10

      # Use intelligent waiting - assert_selector will wait automatically
      assert_selector '#attachments-section', wait: 10

      # Use intelligent waiting for element finding
      assert_selector('button[data-modal-id="incomeProofReviewModal"]')
      find('button[data-modal-id="incomeProofReviewModal"]').click

      within('#incomeProofReviewModal') do
        assert_selector('button', text: 'Reject')
        click_button 'Reject'
      end

      within('#proofRejectionModal') do
        # Wait for proof type field and verify it's set correctly
        assert_selector('#rejection-proof-type', visible: false)
        proof_type_field = find('#rejection-proof-type', visible: false)
        assert_equal 'income', proof_type_field.value

        # Check that all common rejection reason buttons are visible
        assert_selector "button[data-reason-type='addressMismatch']", text: 'Address Mismatch'
        assert_selector "button[data-reason-type='expired']", text: 'Expired Documentation'
        assert_selector "button[data-reason-type='missingName']", text: 'Missing Name'
        assert_selector "button[data-reason-type='wrongDocument']", text: 'Wrong Document Type'

        # Check for income-specific buttons
        assert_selector "button[data-reason-type='missingAmount']", text: 'Missing Amount'
        assert_selector "button[data-reason-type='exceedsThreshold']", text: 'Income Exceeds Threshold'
        assert_selector "button[data-reason-type='outdatedSsAward']", text: 'Outdated SS Award Letter'

        # Close the modal to prevent interference with subsequent tests
        click_button 'Cancel'
      end
    end

    test 'admin can see appropriate rejection reasons when rejecting residency proof' do
      # Always sign in fresh for each test
      system_test_sign_in(@admin)
      visit admin_application_path(@application)

      # Wait for page to load completely with intelligent waiting
      # Use a more specific selector that indicates the page has fully loaded
      assert_selector 'h1#application-title', wait: 10

      # Use intelligent waiting - assert_selector will wait automatically
      assert_selector('#attachments-section', wait: 10)

      # Use intelligent waiting for element finding
      assert_selector('button[data-modal-id="residencyProofReviewModal"]')
      find('button[data-modal-id="residencyProofReviewModal"]').click

      within('#residencyProofReviewModal') do
        assert_selector('button', text: 'Reject')
        click_button 'Reject'
      end

      within('#proofRejectionModal') do
        # Wait for modal to be initialized and check proof type
        assert_selector('#rejection-proof-type', visible: false)
        proof_type_value = find('#rejection-proof-type', visible: false).value
        assert_equal 'residency', proof_type_value

        # Check that common rejection reason buttons are visible
        assert_selector "button[data-reason-type='addressMismatch']", text: 'Address Mismatch'
        assert_selector "button[data-reason-type='expired']", text: 'Expired Documentation'
        assert_selector "button[data-reason-type='missingName']", text: 'Missing Name'
        assert_selector "button[data-reason-type='wrongDocument']", text: 'Wrong Document Type'

        # Check that income-specific rejection reason buttons are hidden
        assert_selector "button[data-reason-type='missingAmount']", visible: false
        assert_selector "button[data-reason-type='exceedsThreshold']", visible: false
        assert_selector "button[data-reason-type='outdatedSsAward']", visible: false

        # Close the modal to prevent interference with subsequent tests
        click_button 'Cancel'
      end
    end

    test 'clicking a rejection reason button populates the reason field' do
      # Always sign in fresh for each test
      system_test_sign_in(@admin)
      visit admin_application_path(@application)

      # Wait for page to load completely with intelligent waiting
      # Use a more specific selector that indicates the page has fully loaded
      assert_selector 'h1#application-title', wait: 10

      # Use intelligent waiting - assert_selector will wait automatically
      assert_selector('button[data-modal-id="incomeProofReviewModal"]', wait: 15)
      # Use a fresh find to avoid stale element references
      modal_button = find('button[data-modal-id="incomeProofReviewModal"]', wait: 10)
      modal_button.click

      within('#incomeProofReviewModal') do
        click_button 'Reject'
      end

      # Wait for rejection modal to appear and elements to be ready
      within('#proofRejectionModal') do
        # Wait for the missing name button to be available and click it
        find("button[data-reason-type='missingName']").click

        # Wait for textarea to be populated - use intelligent waiting
        assert_selector("textarea[name='rejection_reason']")

        # Verify the field gets populated with the expected content
        reason_field = find("textarea[name='rejection_reason']")
        assert reason_field.value.present?, 'Rejection reason field should be populated'
        assert_includes reason_field.value, 'does not show your name'

        # Close the modal to prevent interference with subsequent tests
        click_button 'Cancel'
      end
    end

    test 'admin can modify the rejection reason text' do
      # Always sign in fresh for each test
      system_test_sign_in(@admin)
      visit admin_application_path(@application)

      # Wait for page to load completely with intelligent waiting
      # Use a more specific selector that indicates the page has fully loaded
      assert_selector 'h1#application-title', wait: 10

      # Use intelligent waiting - assert_selector will wait automatically
      assert_selector('#attachments-section', wait: 10)

      # Use intelligent waiting for element finding
      assert_selector('button[data-modal-id="incomeProofReviewModal"]')
      find('button[data-modal-id="incomeProofReviewModal"]').click

      within('#incomeProofReviewModal') do
        click_button 'Reject'
      end

      within('#proofRejectionModal') do
        # Click a rejection reason button and wait for population
        find("button[data-reason-type='missingName']").click

        # Wait for the textarea to be populated after button click
        assert_selector("textarea[name='rejection_reason']")

        # Verify field is populated, then modify it
        reason_field = find("textarea[name='rejection_reason']")
        assert reason_field.value.present?, 'Field should be populated before modification'

        # Clear and modify the reason text
        custom_message = 'Please provide a document with your full legal name clearly visible.'
        reason_field.set(custom_message)

        # Verify the custom message was set correctly
        assert_equal custom_message, reason_field.value

        # Close the modal to prevent interference with subsequent tests
        click_button 'Cancel'
      end
    end
  end
end
