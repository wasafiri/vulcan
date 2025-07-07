# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class ApplicationAuditLogTest < ApplicationSystemTestCase
    include ActiveStorageHelper
    include ActionDispatch::TestProcess::FixtureFile

    setup do
      @admin = create(:admin)
      @evaluator = create(:user, :evaluator)
      @medical_provider = create(:user, :medical_provider)
      @application = create(:application, :draft)

      setup_active_storage_test
      sign_in(@admin)
    end

    teardown do
      clear_active_storage
    end

    test 'admin can see application status changes in audit log' do
      # Go to edit page to change status
      visit edit_admin_application_path(@application)

      # Change application status
      select 'In Progress', from: 'Status'
      click_button 'Update Application'
      wait_for_turbo

      # Should redirect back to show page
      assert_current_path admin_application_path(@application)

      # Wait for audit log to update and verify entry
      within '#audit-logs' do
        # Wait for the new entry to appear with longer timeout
        find('tr', text: 'Status Change', wait: 15)

        # Now verify all the text
        assert_text 'Status Change'
        assert_text 'Application submitted for review'
        assert_text @admin.full_name
      end
    end

    test 'admin can see proof review history in audit log' do
      # First attach the proof using service (non-browser action)
      result = ProofAttachmentService.attach_proof(
        application: @application,
        proof_type: :income,
        blob_or_file: fixture_file_upload(Rails.root.join('test/fixtures/files/income_proof.pdf'), 'application/pdf'),
        status: :not_reviewed,
        admin: @admin,
        submission_method: :paper
      )
      assert result[:success], "Failed to attach proof: #{result[:error]&.message}"
      @application.reload

      # Now handle browser interactions
      visit admin_application_path(@application)
      wait_for_turbo

        # Open review modal and wait for it to be visible
        find("button[data-modal-id='incomeProofReviewModal']").click
        assert_selector '#incomeProofReviewModal', visible: true

        # Click reject to transition into rejection modal
        within '#incomeProofReviewModal' do
          click_button 'Reject'
        end

        # Wait for rejection modal to open (original modal may remain in DOM but obscured)
        assert_selector '#proofRejectionModal', visible: true, wait: 10

        # Fill in rejection reason
        within '#proofRejectionModal' do
          # Click rejection reason, Stimulus will populate textarea
          click_button 'Wrong Document Type'

          # Wait for the textarea to appear and be populated (text may vary slightly)
          reason_field = find("textarea[name='rejection_reason']", wait: 5)
          reason_field.click

          # Wait for validation to complete
          assert_no_selector '.border-red-500', # Ensure no validation errors
                             wait: 5

          # Submit form and wait for modal to close
          click_button 'Submit'
          assert_no_selector '#proofRejectionModal', wait: 5
        end

        # Wait for page to update and application to reload
        @application.reload
        wait_for_turbo

        # Wait for audit log to update
        within '#audit-logs' do
          # Wait for the new entry to appear with longer timeout
          find('tr', text: 'Admin Review', wait: 15)

          # Now verify all the text
          assert_text 'Admin rejected Income proof - The document you submitted is not an acceptable type of income proof'
          assert_text @admin.full_name
        end
    end

    test 'admin can see medical certification activity in audit log' do
      # Ensure medical certification status allows sending request
      @application.update!(medical_certification_status: 'not_requested')
      
      visit admin_application_path(@application)

      # Request medical certification
      accept_confirm do
        click_button 'Send Request'
      end
      wait_for_turbo

      # Wait for audit log to update and verify entry
      within '#audit-logs' do
        # Wait for the new entry to appear with longer timeout
        find('tr', text: 'Medical certification requested', wait: 15)

        # Now verify all the text
        assert_text "Medical certification requested from #{@application.medical_provider_name}"
        assert_text @admin.full_name
      end
    end

    test 'admin can see evaluator assignments in audit log' do
      # First approve the application so evaluator assignment becomes available
      @application.update!(status: 'approved')
      
      visit admin_application_path(@application)

      # Assign evaluator (browser confirm not needed in headless tests)
      click_button "Assign #{@evaluator.full_name}"
      wait_for_turbo

      # Wait for audit log to update and verify entry
      within '#audit-logs' do
        # Wait for evaluator assigned event row
        find('tr', text: 'Evaluator Assigned', wait: 15)

        # Confirm evaluator name present
        assert_text @evaluator.full_name
        assert_text @admin.full_name
      end
    end

    test 'admin can see voucher assignments in audit log' do
      # First approve the application and medical certification so voucher assignment becomes available
      @application.update!(
        status: 'approved',
        medical_certification_status: 'approved'
      )
      
      visit admin_application_path(@application)

      # Assign voucher
      click_button 'Assign Voucher'
      wait_for_turbo

      # Wait for audit log to update and verify entry
      within '#audit-logs' do
        # Wait for the new entry to appear with longer timeout
        find('tr', text: 'Voucher Assigned', wait: 15)

        # Now verify all the text
        assert_text 'Voucher Assigned'
        assert_text @admin.full_name
        assert_match(/Voucher \w+ assigned with value \$\d+\.\d{2}/, page.text)
      end
    end
  end
end
