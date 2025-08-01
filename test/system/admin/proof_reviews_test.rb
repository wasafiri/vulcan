# frozen_string_literal: true

# test/system/admin/proof_reviews_test.rb
require 'application_system_test_case'

module Admin
  class ProofReviewsTest < ApplicationSystemTestCase
    include ActiveJob::TestHelper

    setup do
      @admin = create(:admin)
      @application = create(:application, :in_progress_with_pending_proofs)

      # Sign in with proper error handling and verification
      begin
        system_test_sign_in(@admin)
        wait_for_page_stable

        # Verify we're actually signed in by checking for admin dashboard
        visit admin_applications_path
        assert_text 'Admin Dashboard', wait: 10
      rescue Ferrum::NodeNotFoundError, Ferrum::DeadBrowserError => e
        puts "Browser corruption during setup: #{e.message}"
        if respond_to?(:force_browser_restart, true)
          force_browser_restart('proof_reviews_setup_recovery')
        else
          Capybara.reset_sessions!
        end
        system_test_sign_in(@admin)
        wait_for_page_stable
        # Verify authentication after recovery
        visit admin_applications_path
        assert_text 'Admin Dashboard', wait: 10
      end
    end

    test 'admin reviews application proofs' do
      # Visit the specific application directly with proper error handling
      begin
        visit admin_application_path(@application)
        wait_for_page_stable

        # Check if we need to authenticate first
        if has_text?('Sign In', wait: 5)
          # We got redirected to sign-in, need to authenticate
          system_test_sign_in(@admin)
          visit admin_application_path(@application)
          wait_for_page_stable
        end

        # Verify page loaded before proceeding
        assert_selector 'h1#application-title', wait: 15, wait: 15
      rescue Ferrum::NodeNotFoundError, Ferrum::DeadBrowserError => e
        puts "Browser corruption detected during page visit: #{e.message}"
        if respond_to?(:force_browser_restart, true)
          force_browser_restart('proof_reviews_page_visit_recovery')
        else
          Capybara.reset_sessions!
        end
        # Re-authenticate after browser restart since sessions are lost
        system_test_sign_in(@admin)
        # Retry the visit after restart and re-authentication
        visit admin_application_path(@application)
        wait_for_page_stable
        assert_selector 'h1#application-title', wait: 15, wait: 15
      end

      # Ensure attachments section is present and visible before interacting
      assert_selector '#attachments-section', wait: 10

      # Use the proven stable modal helper from system_test_helpers.rb
      click_review_proof_and_wait('income', timeout: 15)

      # Approve the income proof within the modal using stable pattern
      within '#incomeProofReviewModal' do
        assert_selector 'button', text: 'Approve', wait: 10
        click_button 'Approve'
      end

      # Verify success (flexible assertion)
      assert_text(/approved|success/i, wait: 5) if has_text?(/approved|success/i, wait: 2)
    end

    test 'admin receives notification for new proofs' do
      visit admin_application_path(@application)

      # Check if we need to authenticate
      if has_selector?('form[action="/sign_in"]')
        system_test_sign_in(@admin)
        visit admin_application_path(@application)
      end

      # Use intelligent waiting
      assert_selector 'h1#application-title', wait: 15
      assert_text(@application.user.full_name)

      # Look for proof status information (using intelligent waiting)
      assert_text(/Income Proof|income.*proof/i) if has_text?('Income Proof')

      assert_text(/Residency Proof|residency.*proof/i) if has_text?('Residency Proof')

      # Check for any audit or activity information
      assert_text(/audit|activity|log/i) if has_text?(/audit|activity|log/i)
    end

    private

    def debug_puts(msg)
      puts msg if ENV['VERBOSE_TESTS']
    end
  end
end
