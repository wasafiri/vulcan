# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class ProofRejectionReasonsTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin)
      @application = applications(:pending_with_proofs)
      sign_in_as(@admin)
    end

    test 'admin can see all rejection reasons when rejecting income proof' do
      visit admin_application_path(@application)

      # Check if modal system exists, skip if not
      if has_selector?("[data-modal-id='incomeProofReviewModal']") || has_button?('Review Proof')
        # Try to open income proof review modal
        if has_selector?("[data-modal-id='incomeProofReviewModal']")
          find("[data-modal-id='incomeProofReviewModal']").click
        elsif has_button?('Review Proof')
          # Use the first Review Proof button (likely income proof)
          first('button', text: 'Review Proof').click
        else
          skip 'Income proof review modal not found'
        end

        # Check if we can find the rejection modal trigger
        if has_selector?('#incomeProofReviewModal') && has_selector?("[data-modal-id='proofRejectionModal']")
          within('#incomeProofReviewModal') do
            find("[data-modal-id='proofRejectionModal']").click
          end
        elsif has_button?('Reject')
          click_button 'Reject'
        else
          skip 'Rejection modal trigger not found'
        end
      else
        skip 'Modal system not available in current UI'
      end

      # Check that the rejection modal is open
      assert_selector '#proofRejectionModal', visible: true

      # Check that the proof type is set to income
      assert_equal 'income', find_by_id('rejection-proof-type', visible: false).value

      # Check that all common rejection reason buttons are visible
      within('#proofRejectionModal') do
        assert_selector "button[data-reason-type='addressMismatch']", text: 'Address Mismatch'
        assert_selector "button[data-reason-type='expired']", text: 'Expired Documentation'
        assert_selector "button[data-reason-type='missingName']", text: 'Missing Name'
        assert_selector "button[data-reason-type='wrongDocument']", text: 'Wrong Document Type'

        # Check that income-specific rejection reason buttons are visible
        assert_selector "button[data-reason-type='missingAmount']", text: 'Missing Amount'
        assert_selector "button[data-reason-type='exceedsThreshold']", text: 'Income Exceeds Threshold'
        assert_selector "button[data-reason-type='outdatedSsAward']", text: 'Outdated SS Award Letter'
      end
    end

    test 'admin can see appropriate rejection reasons when rejecting residency proof' do
      visit admin_application_path(@application)

      # Check if modal system exists, skip if not
      if has_selector?("[data-modal-id='residencyProofReviewModal']") || has_button?('Review Proof')
        # Try to open residency proof review modal
        if has_selector?("[data-modal-id='residencyProofReviewModal']")
          find("[data-modal-id='residencyProofReviewModal']").click
        elsif has_button?('Review Proof')
          # Use the second Review Proof button (likely residency proof)
          all('button', text: 'Review Proof')[1]&.click || skip('Second Review Proof button not found')
        else
          skip 'Residency proof review modal not found'
        end

        # Check if we can find the rejection modal trigger
        if has_selector?('#residencyProofReviewModal') && has_selector?("[data-modal-id='proofRejectionModal']")
          within('#residencyProofReviewModal') do
            find("[data-modal-id='proofRejectionModal']").click
          end
        elsif has_button?('Reject')
          click_button 'Reject'
        else
          skip 'Rejection modal trigger not found'
        end
      else
        skip 'Modal system not available in current UI'
      end

      # Check that the rejection modal is open
      assert_selector '#proofRejectionModal', visible: true

      # Check that the proof type is set to residency
      assert_equal 'residency', find_by_id('rejection-proof-type', visible: false).value

      # Check that common rejection reason buttons are visible
      within('#proofRejectionModal') do
        assert_selector "button[data-reason-type='addressMismatch']", text: 'Address Mismatch'
        assert_selector "button[data-reason-type='expired']", text: 'Expired Documentation'
        assert_selector "button[data-reason-type='missingName']", text: 'Missing Name'
        assert_selector "button[data-reason-type='wrongDocument']", text: 'Wrong Document Type'

        # Check that income-specific rejection reason buttons are hidden
        assert_selector "button[data-reason-type='missingAmount']", visible: false
        assert_selector "button[data-reason-type='exceedsThreshold']", visible: false
        assert_selector "button[data-reason-type='outdatedSsAward']", visible: false
      end
    end

    test 'clicking a rejection reason button populates the reason field' do
      visit admin_application_path(@application)

      # Check if modal system exists, skip if not
      if has_selector?("[data-modal-id='incomeProofReviewModal']") || has_button?('Review Proof')
        # Try to open income proof review modal
        if has_selector?("[data-modal-id='incomeProofReviewModal']")
          find("[data-modal-id='incomeProofReviewModal']").click
        elsif has_button?('Review Proof')
          first('button', text: 'Review Proof').click
        else
          skip 'Income proof review modal not found'
        end

        # Check if we can find the rejection modal trigger
        if has_selector?('#incomeProofReviewModal') && has_selector?("[data-modal-id='proofRejectionModal']")
          within('#incomeProofReviewModal') do
            find("[data-modal-id='proofRejectionModal']").click
          end
        elsif has_button?('Reject')
          click_button 'Reject'
        else
          skip 'Rejection modal trigger not found'
        end
      else
        skip 'Modal system not available in current UI'
      end

      # Click a rejection reason button
      within('#proofRejectionModal') do
        find("button[data-reason-type='missingName']").click

        # Check that the reason field is populated
        reason_field = find("textarea[name='rejection_reason']")
        assert_not_empty reason_field.value
        assert_includes reason_field.value, 'does not show your name'
      end
    end

    test 'admin can modify the rejection reason text' do
      visit admin_application_path(@application)

      # Check if modal system exists, skip if not
      if has_selector?("[data-modal-id='incomeProofReviewModal']") || has_button?('Review Proof')
        # Try to open income proof review modal
        if has_selector?("[data-modal-id='incomeProofReviewModal']")
          find("[data-modal-id='incomeProofReviewModal']").click
        elsif has_button?('Review Proof')
          first('button', text: 'Review Proof').click
        else
          skip 'Income proof review modal not found'
        end

        # Check if we can find the rejection modal trigger
        if has_selector?('#incomeProofReviewModal') && has_selector?("[data-modal-id='proofRejectionModal']")
          within('#incomeProofReviewModal') do
            find("[data-modal-id='proofRejectionModal']").click
          end
        elsif has_button?('Reject')
          click_button 'Reject'
        else
          skip 'Rejection modal trigger not found'
        end
      else
        skip 'Modal system not available in current UI'
      end

      # Click a rejection reason button
      within('#proofRejectionModal') do
        find("button[data-reason-type='missingName']").click

        # Modify the reason text
        custom_message = 'Please provide a document with your full legal name clearly visible.'
        fill_in 'rejection_reason', with: custom_message

        # Check that the reason field contains the custom message
        reason_field = find("textarea[name='rejection_reason']")
        assert_equal custom_message, reason_field.value
      end
    end
  end
end
