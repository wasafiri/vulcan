require "test_helper"

class Admin::ScannedProofsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create(:admin)
    @application = create(:application)
    @file = fixture_file_upload(
      Rails.root.join("test/fixtures/files/test_proof.pdf"),
      "application/pdf"
    )
    sign_in @admin
  end

  test "rejects invalid proof types" do
    get new_admin_application_scanned_proof_path(@application, proof_type: "invalid"),
      headers: { accept: "text/html" }

    assert_response :redirect
    assert_match(/Invalid proof type/, flash[:alert])
  end

  test "creates proof with valid parameters" do
    assert_difference -> { ProofSubmissionAudit.count } do
      post admin_application_scanned_proofs_path(@application),
        params: {
          proof_type: "income",
          file: @file
        }
    end

    assert_response :redirect
    assert_match(/successfully uploaded/, flash[:notice])
    assert @application.reload.income_proof.attached?
  end

  test "handles missing files gracefully" do
    post admin_application_scanned_proofs_path(@application),
      params: { proof_type: "income" }

    assert_response :redirect
    assert_match(/Error uploading proof/, flash[:alert])
  end

  test "requires admin authentication" do
    sign_out @admin

    get new_admin_application_scanned_proof_path(@application, proof_type: "income"),
      headers: { accept: "text/html" }

    assert_response :redirect
    assert_match(/sign in/, flash[:alert].downcase)
  end
end
