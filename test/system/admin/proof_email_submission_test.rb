# frozen_string_literal: true

require 'application_system_test_case'
require 'support/action_mailbox_test_helper'

module Admin
  class ProofEmailSubmissionTest < ApplicationSystemTestCase
    include ActionMailboxTestHelper

    setup do
      # Create users and application using factories with unique email
      @admin = create(:admin)
      @constituent_email = "constituent_#{Time.now.to_i}_#{rand(10_000)}@example.com"
      @constituent = create(:constituent, email: @constituent_email)
      @application = create(:application, :old_enough_for_new_application, user: @constituent)

      # Set the application to a status that allows for proof submission.
      # The ProofSubmissionMailbox bounces emails for applications that are not in an active state (e.g. 'draft').
      @application.update!(status: :needs_information)

      # Set up ApplicationMailbox routing for testing
      ApplicationMailbox.instance_eval do
        routing(/proof@/i => :proof_submission)
      end

      # Log in as admin
      system_test_sign_in(@admin)
      wait_for_turbo
    end

    test 'admin can view and approve proof submitted via email' do
      # Create a temporary file for testing
      file_path = Rails.root.join('tmp/income_proof.pdf')
      # Ensure file is large enough to pass size validations (> 1KB)
      File.write(file_path, 'This is a test PDF file that is larger than one kilobyte to ensure it passes all attachment validations in the mailbox. ' * 20)

      # Create and process an inbound email
      inbound_email = create_inbound_email_with_attachment(
        to: 'proof@example.com',
        from: @constituent_email,
        subject: 'Income Proof Submission',
        body: 'Please find my income proof attached.',
        attachment_path: file_path,
        content_type: 'application/pdf'
      )

      inbound_email.route

      # Visit the application page
      visit admin_application_path(@application)

      # Check if the proof is visible - look for the actual text in the view
      assert_text 'Income Proof'
      assert_text '(via email)'

      # Approve the proof using the modal flow
      within '#attachments-section' do
        click_on 'Review Proof'
      end
      within '#incomeProofReviewModal' do
        click_on 'Approve'
      end

      # Verify the proof was approved
      assert_text 'Income proof approved successfully.'

      # Clean up
      FileUtils.rm_f(file_path)
    end

    test 'admin can view and reject proof submitted via email' do
      # Create a temporary file for testing
      file_path = Rails.root.join('tmp/income_proof.pdf')
      # Ensure file is large enough to pass size validations (> 1KB)
      File.write(file_path, 'This is a test PDF file that is larger than one kilobyte to ensure it passes all attachment validations in the mailbox. ' * 20)

      # Create and process an inbound email
      inbound_email = create_inbound_email_with_attachment(
        to: 'proof@example.com',
        from: @constituent_email,
        subject: 'Income Proof Submission',
        body: 'Please find my income proof attached.',
        attachment_path: file_path,
        content_type: 'application/pdf'
      )

      inbound_email.route

      # Visit the application page
      visit admin_application_path(@application)

      # Check if the proof is visible - look for the actual text in the view
      assert_text 'Income Proof'
      assert_text '(via email)'

      # Reject the proof using the modal flow
      within '#attachments-section' do
        click_on 'Review Proof'
      end

      # Wait for the review modal to appear
      assert_selector '#incomeProofReviewModal', visible: true

      within '#incomeProofReviewModal' do
        click_on 'Reject'
      end

      # Wait for the rejection modal to appear
      assert_selector '#proofRejectionModal', visible: true

      within '#proofRejectionModal' do
        # Manually set the proof type since the JS controller might not work in tests
        page.execute_script("document.getElementById('rejection-proof-type').value = 'income'")

        # Select a predefined rejection reason by clicking one of the buttons
        click_on 'Wrong Document Type'

        # Fill out the additional notes field with our custom message
        find('textarea[name="notes"]').set('Document is illegible')

        click_on 'Submit'
      end

      # Wait for turbo to finish processing the form submission
      wait_for_turbo

      # Verify the proof was rejected - look for the flash message or status change
      # The flash message should appear at the top of the page
      assert_text 'Income proof rejected successfully.'

      # Clean up
      FileUtils.rm_f(file_path)
    end

    test 'admin can view multiple proof types submitted via separate emails' do
      # Create temporary files for testing
      income_file_path = Rails.root.join('tmp/income_proof.pdf')
      residency_file_path = Rails.root.join('tmp/residency_proof.pdf')

      File.write(income_file_path, 'This is income proof file, padded to be larger than 1KB. ' * 50)
      File.write(residency_file_path, 'This is residency proof file, padded to be larger than 1KB. ' * 50)

      # Create and process first email for income proof
      income_email = create_inbound_email_with_attachment(
        to: 'proof@example.com',
        from: @constituent_email,
        subject: 'Income Proof Submission',
        body: 'Please find my income proof attached.',
        attachment_path: income_file_path,
        content_type: 'application/pdf'
      )
      income_email.route

      # Create and process second email for residency proof
      residency_email = create_inbound_email_with_attachment(
        to: 'proof@example.com',
        from: @constituent_email,
        subject: 'Residency Proof Submission',
        body: 'Please find my residency proof attached.',
        attachment_path: residency_file_path,
        content_type: 'application/pdf'
      )
      residency_email.route

      # Visit the application page
      visit admin_application_path(@application)

      # Check if both proof types are visible
      assert_text 'Income Proof'
      assert_text 'Residency Proof'
      # Should see email submission indicator for both
      assert_text '(via email)', count: 2
      assert_text 'income_proof.pdf'
      assert_text 'residency_proof.pdf'

      # Clean up
      FileUtils.rm_f(income_file_path)
      FileUtils.rm_f(residency_file_path)
    end
  end
end
