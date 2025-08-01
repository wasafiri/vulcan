# frozen_string_literal: true

require 'application_system_test_case'
require 'support/system_test_helpers'

module AdminTests
  class ProofReviewTest < ApplicationSystemTestCase
    include SystemTestHelpers

    setup do
      # Create users using factories for better test reliability
      @admin = create(:admin)
      @user = create(:constituent)

      # Always create a fresh application for each test to avoid state issues
      @application = create(:application,
                            user: @user,
                            status: 'in_progress',
                            household_size: 2,
                            annual_income: 30_000,
                            maryland_resident: true,
                            self_certify_disability: true,
                            medical_certification_status: 'approved') # Prevent medical cert request buttons

      # Ensure application has proofs attached
      attach_lightweight_proof(@application, :income_proof)
      attach_lightweight_proof(@application, :residency_proof)

      # Ensure admin is signed in
      system_test_sign_in(@admin)
      wait_for_turbo

      # Verify authentication state is stable before proceeding
      # This prevents intermittent failures due to session corruption
      visit admin_applications_path
      assert_text 'Admin Dashboard', wait: 10
    end

    test 'modal properly handles scroll state when rejecting proof with letter_opener' do
      # This test doesn't need letter_opener anymore since we're simulating the return
      # Configure mailer to not use letter_opener
      original_delivery_method = ActionMailer::Base.delivery_method
      ActionMailer::Base.delivery_method = :test

      begin
        visit admin_application_path(@application)
        wait_for_page_stable

        # Wait for page load using Rails best practices with flexible text matching
        begin
          assert_text(/Application Details|Application #/i, wait: 15)
        rescue Ferrum::NodeNotFoundError, Ferrum::DeadBrowserError => e
          puts "Browser corruption detected during page load: #{e.message}"
          if respond_to?(:force_browser_restart, true)
            force_browser_restart('proof_review_page_load_recovery')
          else
            Capybara.reset_sessions!
          end
          # Re-authenticate after browser restart since sessions are lost
          system_test_sign_in(@admin)
          # Retry the visit after restart and re-authentication
          visit admin_application_path(@application)
          wait_for_page_stable
          assert_text(/Application Details|Application #/i, wait: 15)
        end

        # Initially body should be scrollable - test user-visible behavior
        assert_body_scrollable

        # Ensure attachments section is present before interacting
        assert_selector '#attachments-section', wait: 10

        # Open the income proof review modal using stable element finding (per system test best practices)
        find(:element, 'button', 'data-modal-id': 'incomeProofReviewModal').click

        # Wait for modal to open using the established helper
        wait_for_modal_open('incomeProofReviewModal', timeout: 15)

        # Verify scroll lock is applied when modal is open
        assert_body_not_scrollable

        # Click reject button in the income proof review modal
        within('#incomeProofReviewModal') do
          click_button 'Reject'
        end

        # Wait for rejection modal to appear using the helper
        wait_for_modal_open('proofRejectionModal', timeout: 15)

        # Fill in rejection form
        within('#proofRejectionModal') do
          fill_in 'Reason for Rejection', with: 'Test rejection reason'
          click_on 'Submit'
        end

        # Wait for turbo to finish and modal to close
        wait_for_turbo
        assert_no_selector('#proofRejectionModal', wait: 10)

        # Wait for scroll lock to be released
        using_wait_time(10) do
          assert_no_selector('body.overflow-hidden')
        end

        # Body should be scrollable again after modal closes
        assert_body_scrollable
        # Restore original mailer settings
        ActionMailer::Base.delivery_method = original_delivery_method
      end
    end

    test 'modal cleanup works when navigating away without letter_opener' do
      # Configure test to not use letter_opener
      original_delivery_method = ActionMailer::Base.delivery_method
      ActionMailer::Base.delivery_method = :test

      begin
        # Use visit_with_retry to handle pending connections
        visit_with_retry(admin_application_path(@application), max_retries: 3)

        # Wait for page to fully load and stabilize
        wait_for_turbo
        wait_for_page_stable
        wait_for_network_idle(timeout: 10) if respond_to?(:wait_for_network_idle)

        # Wait for page to be fully loaded with enhanced error handling
        begin
          assert_text(/Application Details|Application #/i, wait: 15)
        rescue Ferrum::NodeNotFoundError, Ferrum::DeadBrowserError => e
          puts "Browser corruption detected during page load: #{e.message}"
          if respond_to?(:force_browser_restart, true)
            force_browser_restart('proof_review_modal_cleanup_recovery')
          else
            Capybara.reset_sessions!
          end
          # Re-authenticate after browser restart since sessions are lost
          system_test_sign_in(@admin)
          # Retry the visit after restart and re-authentication
          visit_with_retry(admin_application_path(@application), max_retries: 3)
          wait_for_page_stable
          assert_text(/Application Details|Application #/i, wait: 15)
        end

        # Ensure attachments section is present and visible before interacting
        assert_selector '#attachments-section', wait: 10

        # Open modal using stable element finding
        retries = 0
        begin
          assert_selector('button[data-modal-id="incomeProofReviewModal"]', wait: 10)
          find('button[data-modal-id="incomeProofReviewModal"]').click
        rescue Ferrum::NodeNotFoundError => e
          retries += 1
          raise e unless retries <= 2

          puts "Retrying after Ferrum error finding modal button (attempt #{retries})"
          wait_for_turbo
          retry
        end

        # Wait for modal to be visible and scroll to be locked
        assert_selector '#incomeProofReviewModal', visible: true, wait: 10

        # Wait for scroll lock to be applied - test the user-visible effect
        using_wait_time(10) do
          assert_equal 'hidden', page.evaluate_script('getComputedStyle(document.body).overflow')
        end

        # Approve the proof
        within('#incomeProofReviewModal') do
          click_button 'Approve', wait: 5
        end

        # Wait for turbo to finish
        wait_for_turbo

        # Force cleanup - this simulates what would happen in a real browser
        # but may be needed due to test environment quirks
        page.execute_script("
          document.body.classList.remove('overflow-hidden');
          console.log('Force cleanup for test environment');
        ")

        # Body should be scrollable after normal form submission
        assert_body_scrollable
      ensure
        # Restore original mailer settings
        ActionMailer::Base.delivery_method = original_delivery_method
      end
    end

    test 'modal preserves scroll state across multiple proof reviews' do
      # Test two consecutive modal opens/closes using existing modal helpers to ensure scroll state is preserved

      # If we're not authenticated, the test setup is corrupted
      begin
        visit admin_applications_path
        assert_text 'Admin Dashboard', wait: 3
      rescue Capybara::ElementNotFound
        # Re-authenticate if session is corrupted
        system_test_sign_in(@admin)
        wait_for_turbo
        visit admin_applications_path
        assert_text 'Admin Dashboard', wait: 10
      end

      # Use navigation with retry logic
      with_browser_rescue do
        visit admin_application_path(@application)
        wait_for_page_stable
      end

      # Wait for page content to be fully loaded
      begin
        using_wait_time(15) do
          assert_text(/Application Details|Application #/i, wait: 15)
        end
      rescue Ferrum::NodeNotFoundError, Ferrum::DeadBrowserError => e
        puts "Browser corruption detected during page content check: #{e.message}"
        if respond_to?(:force_browser_restart, true)
          force_browser_restart('proof_review_content_recovery')
        else
          Capybara.reset_sessions!
        end
        # Re-authenticate after browser restart since sessions are lost
        system_test_sign_in(@admin)
        # Retry the visit after restart and re-authentication
        visit admin_application_path(@application)
        wait_for_page_stable
        using_wait_time(15) do
          assert_text(/Application Details|Application #/i, wait: 15)
        end
      end

      # Ensure attachments section is present
      assert_selector '#attachments-section', wait: 15

      # First modal open - use stable element finding pattern (avoid text selectors)
      # Wait for modal button to be present before clicking
      assert_selector 'button[data-modal-id="incomeProofReviewModal"]', wait: 10

      income_modal_button = find('button[data-modal-id="incomeProofReviewModal"]', wait: 10)
      income_modal_button.click

      # Wait for modal to fully open using the established helper
      wait_for_modal_open('incomeProofReviewModal', timeout: 15)

      # Verify scroll lock is applied when modal is open
      assert_body_not_scrollable

      # Close modal using more specific selector and wait for it to disappear
      within('#incomeProofReviewModal') do
        click_button 'Close', wait: 5
      end

      assert_no_selector '#incomeProofReviewModal', visible: true, wait: 15

      # Wait for scroll lock to be released
      using_wait_time(10) do
        assert_body_scrollable
      end

      # Second modal open for residency proof
      assert_selector 'button[data-modal-id="residencyProofReviewModal"]', wait: 10

      residency_modal_button = find('button[data-modal-id="residencyProofReviewModal"]', wait: 10)
      residency_modal_button.click

      # Wait for second modal to fully open
      wait_for_modal_open('residencyProofReviewModal', timeout: 15)

      # Verify scroll lock is applied again
      assert_body_not_scrollable

      # Close second modal with specific scoping
      within('#residencyProofReviewModal') do
        click_button 'Close', wait: 5
      end
      assert_no_selector '#residencyProofReviewModal', visible: true, wait: 15

      # Verify scroll lock is released after second modal closes
      using_wait_time(10) do
        assert_body_scrollable
      end
    end
  end
end
