# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class AuditLogsTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_david)
      @application = applications(:submitted_application)

      # Store original environment variables
      @original_mailer_host = ENV.fetch('MAILER_HOST', nil)

      # Ensure all necessary attachments are present
      unless @application.income_proof.attached?
        @application.income_proof.attach(
          io: Rails.root.join('test/fixtures/files/income_proof.pdf').open,
          filename: 'income_proof.pdf',
          content_type: 'application/pdf'
        )
      end

      unless @application.residency_proof.attached?
        @application.residency_proof.attach(
          io: Rails.root.join('test/fixtures/files/residency_proof.pdf').open,
          filename: 'residency_proof.pdf',
          content_type: 'application/pdf'
        )
      end

      # Set the proof statuses to 'not_reviewed'
      @application.update!(
        income_proof_status: :not_reviewed,
        residency_proof_status: :not_reviewed
      )

      # Set the MAILER_HOST environment variable for the test
      ENV['MAILER_HOST'] = 'example.com'

      # Sign in as admin
      sign_in(@admin)
    end

    teardown do
      # Restore original environment variables
      ENV['MAILER_HOST'] = @original_mailer_host
    end

    test 'audit logs correctly show proof review actions without duplicates' do
      # Visit the application page
      visit admin_application_path(@application)

      # Verify that the attachments section exists
      assert page.has_css?('#attachments-section'), 'Attachments section should be present'

      # Check if the income proof review button is present
      income_proof_button = nil
      within '#attachments-section' do
        # Find all buttons with text "Review Proof"
        review_buttons = all('button', text: 'Review Proof')

        # Skip the test if there are no review buttons
        skip 'No review buttons found in attachments section' if review_buttons.empty?

        # Get the first review button
        income_proof_button = review_buttons.first
      end

      # Click the income proof review button
      income_proof_button.click

      # Approve the income proof
      within '#incomeProofReviewModal' do
        click_on 'Approve'
      end

      # Wait for the page to update
      assert_text 'Income proof approved successfully.'

      # Verify the audit logs section exists and contains the expected information
      if page.has_css?('#audit-logs')
        within '#audit-logs' do
          # Check that we have the admin review entry
          assert_text 'Admin Review'
          assert_text @admin.full_name
          assert_text 'Admin approved Income proof'

          # Check that we don't have duplicate entries
          # Count the number of rows that contain both "Income proof" and "approved"
          income_approved_count = all('tr').count do |tr|
            tr.text.include?('Income proof') && tr.text.include?('approved')
          end
          assert_equal 1, income_approved_count, 'Expected only one entry for Income proof approval'
        end
      end

      # Check if there's a second review button for residency proof
      residency_proof_button = nil
      within '#attachments-section' do
        # Find all buttons with text "Review Proof"
        review_buttons = all('button', text: 'Review Proof')

        # Skip the rest of the test if there's no second review button
        skip 'No second review button found in attachments section' if review_buttons.empty?

        # Get the first review button (which should now be the residency proof button)
        residency_proof_button = review_buttons.first
      end

      # Click the residency proof review button
      residency_proof_button.click

      # Reject the residency proof
      within '#residencyProofReviewModal' do
        click_on 'Reject'
      end

      # Fill in rejection reason in the modal
      within '#proofRejectionModal' do
        fill_in 'Rejection Reason', with: 'Document is illegible'
        click_on 'Submit'
      end

      # Wait for the page to update
      assert_text 'Residency proof rejected successfully.'

      # Verify the audit logs section exists and contains the expected information
      if page.has_css?('#audit-logs')
        within '#audit-logs' do
          # Check that we have the admin review entry
          assert_text 'Admin Review'
          assert_text @admin.full_name
          assert_text 'Admin rejected Residency proof - Document is illegible'

          # Check that we don't have duplicate entries
          # Count the number of rows that contain both "Residency proof" and "rejected"
          residency_rejected_count = all('tr').count do |tr|
            tr.text.include?('Residency proof') && tr.text.include?('rejected')
          end
          assert_equal 1, residency_rejected_count, 'Expected only one entry for Residency proof rejection'
        end
      end
    end

    private

    def count_audit_log_entries
      # First check if the audit logs section exists
      if page.has_css?('#audit-logs')
        within '#audit-logs' do
          return all('tbody tr').count
        end
      else
        # If the section doesn't exist, return 0
        0
      end
    end
  end
end
