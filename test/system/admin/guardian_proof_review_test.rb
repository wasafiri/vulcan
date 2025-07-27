# frozen_string_literal: true

require 'application_system_test_case'

module AdminTests
  class GuardianProofReviewTest < ApplicationSystemTestCase
    setup do
      @admin = create(:admin)
      @application = create(:application, :in_progress_with_pending_proofs, :submitted_by_guardian, :old_enough_for_new_application)

      # Use standard sign in
      system_test_sign_in(@admin)
      assert_text 'Dashboard', wait: 10 # Verify we're signed in with increased wait time
    end

    test 'displays guardian alert in income proof review modal' do
      visit admin_application_path(@application)
      wait_for_turbo(timeout: 15)
      
      # Ensure page is fully loaded with comprehensive error handling
      retry_count = 0
      begin
        # First, wait for basic page structure
        using_wait_time(30) do
          assert_selector 'body', wait: 30
          assert_selector 'main', wait: 30
        end
        
        # Then wait for attachments section with additional debugging
        using_wait_time(30) do
          begin
            assert_selector '#attachments-section', wait: 30
          rescue => e
            puts "DEBUG: Page title: #{page.title}"
            puts "DEBUG: Current path: #{current_path}"
            puts "DEBUG: Page has body: #{page.has_selector?('body')}"
            puts "DEBUG: Page has main: #{page.has_selector?('main')}" 
            raise e
          end
        end
        
        # Wait for proof attachments to be processed by checking for specific proof sections
        using_wait_time(20) do
          assert_selector '#attachments-section', text: 'Income Proof', wait: 20
          assert_selector '#attachments-section', text: 'Residency Proof', wait: 20
        end
      rescue Ferrum::NodeNotFoundError, Ferrum::TimeoutError => e
        retry_count += 1
        if retry_count < 3  # Increased retry attempts
          puts "Ferrum error encountered in income test, retrying... (attempt #{retry_count})"
          puts "Error: #{e.message}"
          # Try refreshing the page on retry
          visit admin_application_path(@application) if retry_count == 2
          sleep 3
          retry
        else
          puts "Ferrum error persisted after retries in income test: #{e.message}"
          # Save screenshot for debugging
          save_screenshot("debug_income_test_failure.png") if respond_to?(:save_screenshot)
          raise e
        end
      end
      
      # Open the income proof review modal with better error handling
      within '#attachments-section' do
        # Look specifically for the income proof review button
        # Use data-modal-id to target the correct button with defensive waiting
        button = find('button[data-modal-id="incomeProofReviewModal"]', wait: 15)
        # Ensure button is actually clickable before clicking
        assert button.visible?
        button.click
      end
      wait_for_turbo

      # Verify the guardian alert is displayed
      within '#incomeProofReviewModal' do
        assert_text 'Guardian Application', wait: 5
        assert_text 'This application was submitted by a Guardian User (parent) on behalf of a dependent', wait: 5
        assert_text 'Please verify this relationship when reviewing these proof documents', wait: 5
      end
    end

    test 'displays guardian alert in residency proof review modal' do
      visit admin_application_path(@application)
      wait_for_turbo(timeout: 15)
      
      # Ensure page is fully loaded with comprehensive error handling
      retry_count = 0
      begin
        # First, wait for basic page structure
        using_wait_time(30) do
          assert_selector 'body', wait: 30
          assert_selector 'main', wait: 30
        end
        
        # Then wait for attachments section with additional debugging
        using_wait_time(30) do
          begin
            assert_selector '#attachments-section', wait: 30
          rescue => e
            puts "DEBUG: Page title: #{page.title}"
            puts "DEBUG: Current path: #{current_path}"
            puts "DEBUG: Page has body: #{page.has_selector?('body')}"
            puts "DEBUG: Page has main: #{page.has_selector?('main')}" 
            raise e
          end
        end
        
        # Wait for proof attachments to be processed by checking for specific proof sections
        using_wait_time(20) do
          assert_selector '#attachments-section', text: 'Income Proof', wait: 20
          assert_selector '#attachments-section', text: 'Residency Proof', wait: 20
        end
      rescue Ferrum::NodeNotFoundError, Ferrum::TimeoutError => e
        retry_count += 1
        if retry_count < 3  # Increased retry attempts
          puts "Ferrum error encountered in residency test, retrying... (attempt #{retry_count})"
          puts "Error: #{e.message}"
          # Try refreshing the page on retry
          visit admin_application_path(@application) if retry_count == 2
          sleep 3
          retry
        else
          puts "Ferrum error persisted after retries in residency test: #{e.message}"
          # Save screenshot for debugging
          save_screenshot("debug_residency_test_failure.png") if respond_to?(:save_screenshot)
          raise e
        end
      end

      # Open the residency proof review modal with safe interaction
      within '#attachments-section' do
        # Click the button with the specific data attribute for residency proof
        button = find('button[data-modal-id="residencyProofReviewModal"]', wait: 15)
        # Ensure button is actually clickable before clicking
        assert button.visible?
        button.click
      end
      wait_for_turbo

      # Verify the guardian alert is displayed
      within '#residencyProofReviewModal' do
        assert_text 'Guardian Application', wait: 5
        assert_text 'This application was submitted by a Guardian User (parent) on behalf of a dependent', wait: 5
        assert_text 'Please verify this relationship when reviewing these proof documents', wait: 5
      end
    end

    test 'does not display guardian alert for non-guardian applications' do
      # Create a regular application (not from a guardian)
      # The default constituent factory should not create a guardian or dependent under the new schema.
      # Use a unique email to ensure we don't conflict with existing users
      regular_constituent = create(:constituent, email: "regular_test_#{Time.now.to_i}_#{rand(10_000)}@example.com")
      regular_application = create(:application, :in_progress_with_pending_proofs, :old_enough_for_new_application, user: regular_constituent)

      # Manually attach proofs since the factory trait isn't working properly
      regular_application.income_proof.attach(
        io: Rails.root.join('test/fixtures/files/medical_certification_valid.pdf').open,
        filename: 'income_proof.pdf',
        content_type: 'application/pdf'
      )
      regular_application.residency_proof.attach(
        io: Rails.root.join('test/fixtures/files/medical_certification_valid.pdf').open,
        filename: 'residency_proof.pdf',
        content_type: 'application/pdf'
      )

      visit admin_application_path(regular_application)
      wait_for_turbo(timeout: 15)
      
      # Ensure page is fully loaded with comprehensive error handling
      # The regular application might have different loading patterns
      retry_count = 0
      begin
        # First, wait for basic page structure
        using_wait_time(30) do
          assert_selector 'body', wait: 30
          assert_selector 'main', wait: 30
        end
        
        # Then wait for attachments section with additional debugging
        using_wait_time(30) do
          begin
            assert_selector '#attachments-section', wait: 30
          rescue => e
            puts "DEBUG: Page title: #{page.title}"
            puts "DEBUG: Current path: #{current_path}"
            puts "DEBUG: Page has body: #{page.has_selector?('body')}"
            puts "DEBUG: Page has main: #{page.has_selector?('main')}" 
            raise e
          end
        end
        
        # Wait for proof attachments to be processed by checking for specific proof sections
        using_wait_time(20) do
          assert_selector '#attachments-section', text: 'Income Proof', wait: 20
          assert_selector '#attachments-section', text: 'Residency Proof', wait: 20
        end
      rescue Ferrum::NodeNotFoundError, Ferrum::TimeoutError => e
        retry_count += 1
        if retry_count < 3  # Increased retry attempts
          puts "Ferrum error encountered in non-guardian test, retrying... (attempt #{retry_count})"
          puts "Error: #{e.message}"
          # Try refreshing the page on retry
          visit admin_application_path(regular_application) if retry_count == 2
          sleep 3
          retry
        else
          puts "Ferrum error persisted after retries in non-guardian test: #{e.message}"
          # Save screenshot for debugging
          save_screenshot("debug_non_guardian_test_failure.png") if respond_to?(:save_screenshot)
          raise e
        end
      end

      # Open the income proof review modal with safe interaction
      within '#attachments-section' do
        # Click the button with the specific data attribute for income proof
        button = find('button[data-modal-id="incomeProofReviewModal"]', wait: 15)
        # Ensure button is actually clickable before clicking
        assert button.visible?
        button.click
      end
      wait_for_turbo

      # Verify the guardian alert is not displayed
      within '#incomeProofReviewModal' do
        assert_no_text 'Guardian Application'
        assert_no_text 'This application was submitted by a'
        assert_no_text 'on behalf of a minor'
      end

      # Close the modal with safe interaction
      # Use text-based clicking which is more resilient
      within '#incomeProofReviewModal' do
        click_button 'Close', wait: 5
      end
      wait_for_turbo

      # Open the residency proof review modal with safe interaction
      within '#attachments-section' do
        # Click the button with the specific data attribute for residency proof
        button = find('button[data-modal-id="residencyProofReviewModal"]', wait: 15)
        # Ensure button is actually clickable before clicking
        assert button.visible?
        button.click
      end
      wait_for_turbo

      # Verify the guardian alert is not displayed
      within '#residencyProofReviewModal' do
        assert_no_text 'Guardian Application'
        assert_no_text 'This application was submitted by a'
        assert_no_text 'on behalf of a minor'
      end
    end
  end
end
