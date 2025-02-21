require "test_helper"

class ProofSubmissionFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  include ActionMailbox::TestHelper

  setup do
    @application = applications(:one)
    @user = users(:constituent)
    @admin = users(:admin)
    @valid_pdf = fixture_file_upload("test/fixtures/files/valid.pdf", "application/pdf")
    sign_in @user
  end

  test "complete web submission flow" do
    # Set up rate limit policy
    Policy.set("proof_submission_rate_limit_web", 5)
    Policy.set("proof_submission_rate_period", 1)

    assert_difference [ "ProofSubmissionAudit.count", "Event.count" ], 1 do
      post resubmit_proof_constituent_application_path(@application),
        params: { proof_type: "income", income_proof: @valid_pdf }
    end

    # Verify audit trail
    audit = ProofSubmissionAudit.last
    assert_equal "web", audit.submission_method
    assert_equal @user, audit.user
    assert_equal @application, audit.application
    assert_equal "income", audit.proof_type
    assert audit.metadata.key?("user_agent")

    # Verify event
    event = Event.last
    assert_equal "proof_submitted", event.action
    assert_equal @application.id, event.metadata["application_id"]
  end

  test "complete email submission flow" do
    # Set up rate limit policy
    Policy.set("proof_submission_rate_limit_email", 10)
    Policy.set("proof_submission_rate_period", 1)

    # Create email with attachment
    email = create_inbound_email_from_mail(
      from: @user.email,
      to: "proofs@example.com",
      subject: "Proof Submission",
      body: "Please find attached my proof document.",
      attachments: {
        "proof.pdf" => @valid_pdf.read
      }
    )

    assert_difference [ "ProofSubmissionAudit.count", "Event.count" ], 1 do
      perform_enqueued_jobs do
        email.route
      end
    end

    # Verify audit trail
    audit = ProofSubmissionAudit.last
    assert_equal "email", audit.submission_method
    assert_equal @user, audit.user
    assert_equal @application, audit.application
    assert audit.metadata.key?("inbound_email_id")

    # Verify event
    event = Event.last
    assert_equal "proof_submitted", event.action
    assert_equal @application.id, event.metadata["application_id"]
  end

  test "handles rate limiting across submission methods" do
    # Set up stricter rate limits for testing
    Policy.set("proof_submission_rate_limit_web", 2)
    Policy.set("proof_submission_rate_limit_email", 2)
    Policy.set("proof_submission_rate_period", 1)

    # Web submissions
    2.times do
      post resubmit_proof_constituent_application_path(@application),
        params: { proof_type: "income", income_proof: @valid_pdf }
      assert_response :redirect
      assert_equal "Proof submitted successfully", flash[:notice]
    end

    # Third web submission should fail
    post resubmit_proof_constituent_application_path(@application),
      params: { proof_type: "income", income_proof: @valid_pdf }
    assert_equal "Please wait before submitting another proof", flash[:alert]

    # Email submissions should still work (separate limit)
    email = create_inbound_email_from_mail(
      from: @user.email,
      to: "proofs@example.com",
      subject: "Proof Submission",
      body: "Please find attached my proof document.",
      attachments: {
        "proof.pdf" => @valid_pdf.read
      }
    )

    assert_difference "ProofSubmissionAudit.count" do
      perform_enqueued_jobs do
        email.route
      end
    end
  end

  test "maintains audit trail across submission methods" do
    # Web submission
    post resubmit_proof_constituent_application_path(@application),
      params: { proof_type: "income", income_proof: @valid_pdf }

    web_audit = ProofSubmissionAudit.last
    assert_equal "web", web_audit.submission_method

    # Email submission
    email = create_inbound_email_from_mail(
      from: @user.email,
      to: "proofs@example.com",
      subject: "Proof Submission",
      attachments: {
        "proof.pdf" => @valid_pdf.read
      }
    )

    perform_enqueued_jobs do
      email.route
    end

    email_audit = ProofSubmissionAudit.last
    assert_equal "email", email_audit.submission_method

    # Admin can view both submissions
    sign_in @admin
    get admin_application_path(@application)
    assert_response :success
    assert_select ".audit-log-entry", count: 2
  end

  test "handles validation errors consistently" do
    invalid_file = fixture_file_upload("test/fixtures/files/invalid.exe", "application/x-msdownload")

    # Web submission with invalid file
    post resubmit_proof_constituent_application_path(@application),
      params: { proof_type: "income", income_proof: invalid_file }
    assert_response :unprocessable_entity

    # Email submission with invalid file
    email = create_inbound_email_from_mail(
      from: @user.email,
      to: "proofs@example.com",
      subject: "Proof Submission",
      attachments: {
        "invalid.exe" => invalid_file.read
      }
    )

    perform_enqueued_jobs do
      email.route
    end

    # Should create error notification
    assert_equal 1, ActionMailer::Base.deliveries.count
    mail = ActionMailer::Base.deliveries.last
    assert_equal "Proof Submission Error", mail.subject
  end

  private

  def sign_in(user)
    post user_session_path, params: {
      user: { email: user.email, password: "password" }
    }
  end
end
