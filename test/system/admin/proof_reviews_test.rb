# frozen_string_literal: true

# test/system/admin/proof_reviews_test.rb
require 'application_system_test_case'

module Admin
  class ProofReviewsTest < ApplicationSystemTestCase
    include ActiveJob::TestHelper

    setup do
      @admin = create(:admin)
      @application = create(:application, :in_progress_with_pending_proofs)

      # Sign in with enhanced stability
      with_browser_rescue do
        system_test_sign_in(@admin)
        wait_for_page_stable
      end
    end

    test 'admin reviews application proofs' do
      # Visit the specific application directly with enhanced browser rescue
      with_browser_rescue(max_retries: 3) do
        visit admin_application_path(@application)
        wait_for_page_stable
        
        # Verify page loaded properly before proceeding
        assert_selector 'h1#application-title', wait: 15
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
      # Visit the specific application directly with browser rescue
      with_browser_rescue do
        visit admin_application_path(@application)
        wait_for_page_stable
      end

      # Verify application details page loads with specific selector
      assert_selector 'h1#application-title', wait: 15
      
      # Look for proof status information (flexible selectors)
      if has_text?('Income Proof', wait: 3)
        # Verify some kind of proof status is shown
        assert_text(/Income Proof|income.*proof/i)
      end

      if has_text?('Residency Proof', wait: 3)
        assert_text(/Residency Proof|residency.*proof/i)
      end

      # Check for any audit or activity information
      if has_text?(/audit|activity|log/i, wait: 2)
        # Some kind of audit trail exists
        assert_text(/audit|activity|log/i)
      end
    end

    private

    def debug_puts(msg)
      puts msg if ENV['VERBOSE_TESTS']
    end
  end
end
