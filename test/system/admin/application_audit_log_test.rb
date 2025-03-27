# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class ApplicationAuditLogTest < ApplicationSystemTestCase
    include ActiveStorageHelper
    include ActionDispatch::TestProcess::FixtureFile

    setup do
      @admin = users(:admin_david)
      @evaluator = users(:evaluator_betsy)
      @medical_provider = users(:medical_provider)
      @application = applications(:draft_application)

      setup_active_storage_test
      sign_in @admin
    end

    teardown do
      clear_active_storage
    end

    test 'admin can see application status changes in audit log' do
      safe_browser_action do
        visit admin_application_path(@application)

        # Change application status
        select 'In Progress', from: 'Status'
        click_button 'Update Status'
        wait_for_complete_page_load

        # Wait for audit log to update and verify entry
        within '#audit-logs' do
          # Wait for the new entry to appear with longer timeout
          find('.audit-log-entry', text: 'Status Change', wait: 15)

          # Now verify all the text
          assert_text 'Status Change'
          assert_text 'Status changed from draft to in_progress'
          assert_text @admin.full_name
        end
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
      safe_browser_action do
        visit admin_application_path(@application)
        wait_for_complete_page_load

        # Open review modal and wait for it to be visible
        find("button[data-modal-id='incomeProofReviewModal']").click
        assert_selector '#incomeProofReviewModal', visible: true

        # Click reject and wait for modals to transition
        within '#incomeProofReviewModal' do
          click_button 'Reject'
        end

        # Wait for review modal to close and rejection modal to open
        assert_no_selector '#incomeProofReviewModal', wait: 5
        assert_selector '#proofRejectionModal', visible: true, wait: 5

        # Fill in rejection reason
        within '#proofRejectionModal' do
          # Wait for proof type to be set by Stimulus controller
          assert_selector "input[name='proof_type'][value='income']", visible: :hidden, wait: 5

          # Click reason and wait for text to be populated by Stimulus controller
          click_button 'Wrong Document Type'

          # Wait for text area to be populated with the predefined reason
          find("textarea[name='rejection_reason']",
               text: 'The document you submitted is not an acceptable type of income proof',
               wait: 5)

          # Wait for text area to be ready for submission
          find("textarea[name='rejection_reason']",
               text: 'The document you submitted is not an acceptable type of income proof',
               wait: 5).click # Focus the field to trigger validation

          # Wait for validation to complete
          assert_no_selector '.border-red-500', # Ensure no validation errors
                             wait: 5

          # Submit form and wait for modal to close
          click_button 'Submit'
          assert_no_selector '#proofRejectionModal', wait: 5
        end

        # Wait for page to update and application to reload
        @application.reload
        wait_for_complete_page_load

        # Wait for Turbo frame to be present and update
        assert_selector 'turbo-frame#audit_logs_frame', wait: 10

        # Wait for audit log to update
        within '#audit-logs' do
          # Wait for the new entry to appear with longer timeout
          find('.audit-log-entry', text: 'Admin Review', wait: 15)

          # Now verify all the text
          assert_text 'Admin rejected Income proof - The document you submitted is not an acceptable type of income proof'
          assert_text @admin.full_name
        end
      end
    end

    test 'admin can see medical certification activity in audit log' do
      safe_browser_action do
        visit admin_application_path(@application)

        # Request medical certification
        accept_confirm do
          click_button 'Send Request'
        end
        wait_for_complete_page_load

        # Wait for audit log to update and verify entry
        within '#audit-logs' do
          # Wait for the new entry to appear with longer timeout
          find('.audit-log-entry', text: 'Medical certification requested', wait: 15)

          # Now verify all the text
          assert_text "Medical certification requested from #{@medical_provider.name}"
          assert_text @admin.full_name
        end
      end
    end

    test 'admin can see evaluator assignments in audit log' do
      safe_browser_action do
        visit admin_application_path(@application)

        # Assign evaluator using the specific button
        accept_confirm do
          click_button "Assign #{@evaluator.full_name}"
        end
        wait_for_complete_page_load

        # Wait for audit log to update and verify entry
        within '#audit-logs' do
          # Wait for the new entry to appear with longer timeout
          find('.audit-log-entry', text: 'Evaluator Assignment', wait: 15)

          # Now verify all the text
          assert_text 'Evaluator Assignment'
          assert_text @admin.full_name
        end
      end
    end

    test 'admin can see voucher assignments in audit log' do
      safe_browser_action do
        visit admin_application_path(@application)

        # Assign voucher
        accept_confirm do
          click_button 'Assign Voucher'
        end
        wait_for_complete_page_load

        # Wait for audit log to update and verify entry
        within '#audit-logs' do
          # Wait for the new entry to appear with longer timeout
          find('.audit-log-entry', text: 'Voucher Assigned', wait: 15)

          # Now verify all the text
          assert_text 'Voucher Assigned'
          assert_text @admin.full_name
          assert_match(/Voucher \w+ assigned with value \$\d+\.\d{2}/, page.text)
        end
      end
    end
  end
end
