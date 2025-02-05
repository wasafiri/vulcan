require "test_helper"

class Admin::ScannedProofsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_david)
    @application = create(:application)
    @file = fixture_file_upload(
      Rails.root.join("test/fixtures/files/test_proof.pdf"),
      "application/pdf"
    )

    # Use the updated sign_in helper which includes headers
    @headers = {
      "HTTP_USER_AGENT" => "Rails Testing",
      "REMOTE_ADDR" => "127.0.0.1"
    }

    post sign_in_path,
      params: { email: @admin.email, password: "password123" },
      headers: @headers

    assert_response :redirect
    follow_redirect!
  end

  def test_rejects_invalid_proof_types
    get new_admin_application_scanned_proof_path(@application, proof_type: "invalid"),
      headers: @headers
    assert_redirected_to admin_application_path(@application)
    assert_equal "Invalid proof type", flash[:alert]
  end

  def test_creates_proof_with_valid_parameters
    assert_difference -> { ProofSubmissionAudit.count } do
      post admin_application_scanned_proofs_path(@application),
        params: {
          proof_type: "income",
          file: @file
        },
        headers: @headers
    end

    assert_redirected_to admin_application_path(@application)
    assert_match(/successfully uploaded/, flash[:notice])
    assert @application.reload.income_proof.attached?
  end

  def test_handles_missing_files
    post admin_application_scanned_proofs_path(@application),
      params: { proof_type: "income" },
      headers: @headers
    assert_redirected_to new_admin_application_scanned_proof_path(@application)
    assert_equal "Please select a file to upload", flash[:alert]
  end

  def test_requires_authentication
    delete sign_out_path, headers: @headers
    get new_admin_application_scanned_proof_path(@application, proof_type: "income"),
      headers: @headers
    assert_redirected_to sign_in_path
    assert_equal "Please sign in to continue", flash[:alert]
  end
end
