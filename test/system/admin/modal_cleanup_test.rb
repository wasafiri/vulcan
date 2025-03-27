# frozen_string_literal: true

require 'application_system_test_case'

module AdminTests
  class ModalCleanupTest < ApplicationSystemTestCase
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

    test 'modal is properly cleaned up after letter_opener returns' do
      skip 'This test requires letter_opener' unless ActionMailer::Base.delivery_method == :letter_opener

      visit admin_application_path(@application)

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

      # Simulate returning from letter_opener tab
      simulate_letter_opener_return

      # Modal should be gone
      assert_no_selector '#proofRejectionModal', visible: true

      # Body should be scrollable again after returning
      assert_body_scrollable
    end

    test 'multiple proof review sequence works correctly' do
      skip 'This test requires letter_opener' unless ActionMailer::Base.delivery_method == :letter_opener

      visit admin_application_path(@application)

      # First rejection - Income proof
      within '#attachments-section' do
        first('button', text: 'Review Proof').click
      end

      click_on 'Reject'
      within '#proofRejectionModal' do
        fill_in 'Reason for Rejection', with: 'Income rejection reason'
        click_on 'Submit'
      end

      # Wait for turbo
      wait_for_turbo

      # Simulate returning from letter_opener
      simulate_letter_opener_return

      # Check that the modal is gone and body is scrollable
      assert_no_selector '#proofRejectionModal', visible: true
      assert_body_scrollable

      # Let the UI settle
      sleep 1

      # Second rejection - Residency proof
      within '#attachments-section' do
        all('button', text: 'Review Proof').last.click
      end

      click_on 'Reject'
      within '#proofRejectionModal' do
        fill_in 'Reason for Rejection', with: 'Residency rejection reason'
        click_on 'Submit'
      end

      # Wait for turbo
      wait_for_turbo

      # Simulate returning from letter_opener
      simulate_letter_opener_return

      # Check that the modal is gone and body is scrollable
      assert_no_selector '#proofRejectionModal', visible: true
      assert_body_scrollable
    end
  end
end
