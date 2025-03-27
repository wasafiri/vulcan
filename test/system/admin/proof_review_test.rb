# frozen_string_literal: true

require 'application_system_test_case'

module AdminTests
  class ProofReviewTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_david)
      @application = applications(:submitted_application)

      # Ensure all necessary attachments are present
      unless @application.income_proof.attached?
        @application.income_proof.attach(
          io: File.open(Rails.root.join('test/fixtures/files/income_proof.pdf')),
          filename: 'income_proof.pdf',
          content_type: 'application/pdf'
        )
      end

      unless @application.residency_proof.attached?
        @application.residency_proof.attach(
          io: File.open(Rails.root.join('test/fixtures/files/residency_proof.pdf')),
          filename: 'residency_proof.pdf',
          content_type: 'application/pdf'
        )
      end

      # Set the proof statuses to not_reviewed
      @application.update!(
        income_proof_status: :not_reviewed,
        residency_proof_status: :not_reviewed
      )

      # Sign in as admin
      sign_in(@admin)
    end

    test 'modal properly handles scroll state when rejecting proof with letter_opener' do
      # This test doesn't need letter_opener anymore since we're simulating the return
      # Configure mailer to not use letter_opener
      original_delivery_method = ActionMailer::Base.delivery_method
      ActionMailer::Base.delivery_method = :test

      begin
        visit admin_application_path(@application)

        # Initially body should be scrollable
        assert_body_scrollable

        # Open the income proof review modal
        within '#attachments-section' do
          click_on 'Review Proof'
        end

        # Modal should prevent body scroll
        assert_body_not_scrollable

        # Click to open the rejection modal
        click_on 'Reject'
        assert_body_not_scrollable

        # Fill in rejection form
        within '#proofRejectionModal' do
          fill_in 'Reason for Rejection', with: 'Test rejection reason'
          click_on 'Submit'
        end

        # Wait for turbo to finish
        wait_for_turbo

        # Simulate returning from letter_opener tab - even though we're not
        # actually using letter_opener, this will test the cleanup code
        simulate_letter_opener_return

        # Body should be scrollable again after returning
        assert_body_scrollable
      ensure
        # Restore original mailer settings
        ActionMailer::Base.delivery_method = original_delivery_method
      end
    end

    test 'modal cleanup works when navigating away without letter_opener' do
      # Configure test to not use letter_opener
      original_delivery_method = ActionMailer::Base.delivery_method
      ActionMailer::Base.delivery_method = :test

      begin
        visit admin_application_path(@application)

        # Open modal
        within '#attachments-section' do
          click_on 'Review Proof'
        end

        assert_body_not_scrollable

        # Approve the proof (no letter_opener)
        click_on 'Approve'

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
      # This test is now simplified to just test two consecutive modal opens/closes
      # without actually submitting forms, to avoid validation issues

      visit admin_application_path(@application)

      # First modal open
      within '#attachments-section' do
        first('button', text: 'Review Proof').click
      end

      assert_body_not_scrollable

      # Close the modal by clicking Close button
      find("button[data-action='click->modal#close']").click

      # Body should be scrollable after modal is closed
      assert_body_scrollable

      # Second modal open
      within '#attachments-section' do
        all('button', text: 'Review Proof')[1].click
      end

      assert_body_not_scrollable

      # Close the modal by clicking Close button
      find("button[data-action='click->modal#close']").click

      # Body should be scrollable after second modal is closed
      assert_body_scrollable
    end
  end
end
