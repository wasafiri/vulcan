require "test_helper"
require "support/action_mailbox_test_helper"

class ProofSubmissionMailboxTest < ActionMailbox::TestCase
  include ActionMailboxTestHelper

  setup do
    @constituent = users(:constituent)
    @application = applications(:active_application)
    @constituent.update(email: "constituent@example.com")
    @application.update(constituent: @constituent)
  end

  test "routes emails to proof_submission mailbox" do
    inbound_email = create_inbound_email_from_mail(
      to: "proof@example.com",
      from: @constituent.email
    )

    assert_equal ProofSubmissionMailbox, inbound_email.mailbox_class
  end

  test "attaches income proof to application" do
    # Create a temporary file for testing
    file_path = Rails.root.join("tmp", "income_proof.pdf")
    File.open(file_path, "w") do |f|
      f.write("This is a test PDF file")
    end

    assert_difference -> { ActiveStorage::Attachment.count } do
      inbound_email = create_inbound_email_with_attachment(
        to: "proof@example.com",
        from: @constituent.email,
        subject: "Income Proof Submission",
        body: "Please find my income proof attached.",
        attachment_path: file_path,
        content_type: "application/pdf"
      )

      inbound_email.route
    end

    # Verify an event was created
    assert Event.exists?(
      user: @constituent,
      action: "proof_submission_received"
    )

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  test "attaches residency proof to application" do
    # Create a temporary file for testing
    file_path = Rails.root.join("tmp", "residency_proof.pdf")
    File.open(file_path, "w") do |f|
      f.write("This is a test PDF file")
    end

    assert_difference -> { ActiveStorage::Attachment.count } do
      inbound_email = create_inbound_email_with_attachment(
        to: "proof@example.com",
        from: @constituent.email,
        subject: "Residency Proof Submission",
        body: "Please find my residency proof attached.",
        attachment_path: file_path,
        content_type: "application/pdf"
      )

      inbound_email.route
    end

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  test "bounces email when constituent not found" do
    assert_no_difference -> { ActiveStorage::Attachment.count } do
      inbound_email = create_inbound_email_from_mail(
        to: "proof@example.com",
        from: "unknown@example.com",
        subject: "Proof Submission"
      )

      assert_emails 1 do
        inbound_email.route
      end
    end

    # Verify the email was bounced
    assert_equal "bounced", ActionMailbox::InboundEmail.last.status
  end
end
