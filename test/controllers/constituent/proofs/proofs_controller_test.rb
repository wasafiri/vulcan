require "test_helper"

# Note: We're using a generic test class name to avoid namespace conflicts
# between the Constituent model class and the constituent namespace in our routes/controllers.
# The controller lives in app/controllers/constituent/proofs but we want to test it without
# modifying production code.
class ConstituentProofsSubmissionTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess::FixtureFile

  fixtures :users, :applications

  setup do
    @application = applications(:one) # Has rejected proofs from fixture
    @user = users(:constituent)
    @valid_pdf = fixture_file_upload("test/fixtures/files/valid.pdf", "application/pdf")
    sign_in @user
  end

  test "submits proof successfully when proof is rejected" do
    assert_changes "@application.reload.income_proof_status",
      from: "rejected",
      to: "not_reviewed" do
        assert_changes "@application.reload.needs_review_since",
          from: nil do
            assert_difference "ProofSubmissionAudit.count" do
              assert_difference "Event.count" do
                # Using raw path instead of route helper due to namespace conflict
                post "/constituent/applications/#{@application.id}/proofs/resubmit",
                  params: { proof_type: "income", income_proof: @valid_pdf }

                # Verify redirect and flash
                assert_redirected_to constituent_application_path(@application)
                assert_equal "Proof submitted successfully", flash[:notice]

                # Verify application updates
                @application.reload
                assert @application.income_proof.attached?, "Income proof should be attached"
                assert_equal "not_reviewed", @application.income_proof_status
                assert_not_nil @application.needs_review_since

                # Verify audit trail
                audit = ProofSubmissionAudit.last
                assert_equal @application, audit.application
                assert_equal @user, audit.user
                assert_equal "income", audit.proof_type
                assert_equal "web", audit.submission_method
                assert_equal "127.0.0.1", audit.ip_address
                assert_equal({ "user_agent" => "Rails Testing", "submission_method" => "web" }, audit.metadata)

                # Verify event was created
                event = Event.last
                assert_equal "proof_submitted", event.action
                assert_equal @application.id, event.metadata["application_id"]
                assert_equal "income", event.metadata["proof_type"]
              end
            end
          end
      end
  end

  test "cannot submit proof if not rejected" do
    @application.update!(income_proof_status: :not_reviewed)

    assert_no_changes "@application.reload.income_proof_status" do
      assert_no_difference [ "ProofSubmissionAudit.count", "Event.count" ] do
        # Using raw path instead of route helper due to namespace conflict
        post "/constituent/applications/#{@application.id}/proofs/resubmit",
          params: { proof_type: "income", income_proof: @valid_pdf }

        assert_redirected_to constituent_application_path(@application)
        assert_equal "Invalid proof type or status", flash[:alert]
        assert_not @application.reload.income_proof.attached?
      end
    end
  end

  test "requires authentication" do
    sign_out

    assert_no_changes "@application.reload.income_proof_status" do
      assert_no_difference [ "ProofSubmissionAudit.count", "Event.count" ] do
        # Using raw path instead of route helper due to namespace conflict
        post "/constituent/applications/#{@application.id}/proofs/resubmit",
          params: { proof_type: "income", income_proof: @valid_pdf }

        assert_redirected_to sign_in_path
        assert_not @application.reload.income_proof.attached?
      end
    end
  end
end
