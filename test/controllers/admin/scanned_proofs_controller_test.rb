# frozen_string_literal: true

require 'test_helper'

module Admin
  class ScannedProofsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @admin = users(:admin_david)
      @application = create(:application)
      @file = fixture_file_upload(
        Rails.root.join('test/fixtures/files/test_proof.pdf'),
        'application/pdf'
      )

      # Use our enhanced sign_in helper
      sign_in_with_headers(@admin)

      # Verify authentication was successful
      assert_authenticated(@admin)
    end

    def test_rejects_invalid_proof_types
      get new_admin_application_scanned_proof_path(@application, proof_type: 'invalid'),
          headers: default_headers
      assert_redirected_to admin_application_path(@application)
      assert_flash_message(:alert, 'Invalid proof type')
    end

    def test_creates_proof_with_valid_parameters
      assert_difference -> { ProofSubmissionAudit.count } do
        post admin_application_scanned_proofs_path(@application),
             params: {
               proof_type: 'income',
               file: @file
             },
             headers: default_headers
      end

      assert_redirected_to admin_application_path(@application)
      assert_flash_message_matches(:notice, /successfully uploaded/)
      assert @application.reload.income_proof.attached?
    end

    def test_handles_missing_files
      post admin_application_scanned_proofs_path(@application),
           params: { proof_type: 'income' },
           headers: default_headers
      assert_redirected_to new_admin_application_scanned_proof_path(@application)
      assert_flash_message(:alert, 'Please select a file to upload')
    end

    def test_requires_authentication
      sign_out_with_headers
      get new_admin_application_scanned_proof_path(@application, proof_type: 'income'),
          headers: default_headers
      assert_redirected_to sign_in_path
      assert_flash_message(:alert, 'Please sign in to continue')
    end
  end
end
