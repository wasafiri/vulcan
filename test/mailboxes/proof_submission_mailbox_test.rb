require "test_helper"
require "support/action_mailbox_test_helper"

class ProofSubmissionMailboxTest < ActionMailbox::TestCase
  include ActionMailboxTestHelper

  setup do
    # Create a constituent and application using factories
    @constituent = create(:constituent)
    @application = create(:application, user: @constituent)
    @constituent.update(email: "constituent@example.com")

    # Create policy records for rate limiting
    create(:policy, :proof_submission_rate_limit_web)
    create(:policy, :proof_submission_rate_limit_email)
    create(:policy, :proof_submission_rate_period)
  end

  test "routes emails to proof_submission mailbox" do
    # Set up ApplicationMailbox routing for testing
    ApplicationMailbox.instance_eval do
      routing(/proof@/i => :proof_submission)
    end

    inbound_email = create_inbound_email_from_mail(
      to: "proof@example.com",
      from: @constituent.email
    )

    # Route the email and check that it was processed by the correct mailbox
    assert_difference -> { ActionMailbox::InboundEmail.where(status: :delivered).count } do
      inbound_email.route
    end

    # Verify it was routed to the correct mailbox by checking the processing status
    assert_equal "delivered", inbound_email.reload.status
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

  test "correctly determines income proof type from subject" do
    inbound_email = create_inbound_email_from_mail(
      to: "proof@example.com",
      from: @constituent.email,
      subject: "Income Proof Document",
      body: "Please find attached my proof."
    )

    mailbox = ProofSubmissionMailbox.new(inbound_email)
    assert_equal :income, mailbox.send(:determine_proof_type, "Income Proof Document", "Please find attached my proof.")
  end

  test "correctly determines residency proof type from subject" do
    inbound_email = create_inbound_email_from_mail(
      to: "proof@example.com",
      from: @constituent.email,
      subject: "Residency Proof Document",
      body: "Please find attached my proof."
    )

    mailbox = ProofSubmissionMailbox.new(inbound_email)
    assert_equal :residency, mailbox.send(:determine_proof_type, "Residency Proof Document", "Please find attached my proof.")
  end

  test "correctly determines proof type from body when subject is ambiguous" do
    inbound_email = create_inbound_email_from_mail(
      to: "proof@example.com",
      from: @constituent.email,
      subject: "Proof Document",
      body: "Please find attached my residency proof."
    )

    mailbox = ProofSubmissionMailbox.new(inbound_email)
    assert_equal :residency, mailbox.send(:determine_proof_type, "Proof Document", "Please find attached my residency proof.")
  end

  test "handles emails with corrupted attachments" do
    # Skip if your validator doesn't check for corrupted files
    skip "Corruption validation not implemented" unless defined?(ProofAttachmentValidator)

    # Create a corrupted PDF file
    file_path = Rails.root.join("tmp", "corrupted.pdf")
    File.open(file_path, "w") do |f|
      f.write("This is not a valid PDF file")
    end

    inbound_email = create_inbound_email_with_attachment(
      to: "proof@example.com",
      from: @constituent.email,
      subject: "Income Proof Submission",
      body: "Please find my income proof attached.",
      attachment_path: file_path,
      content_type: "application/pdf"
    )

    # Mock the ProofAttachmentValidator to raise an error for corrupted files
    ProofAttachmentValidator.stub(:validate!, ->(attachment) {
      raise ProofAttachmentValidator::ValidationError, "File appears to be corrupted"
    }) do
      inbound_email.route
      assert_equal "bounced", inbound_email.status
    end

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  test "handles emails with password-protected attachments" do
    # Skip if your validator doesn't check for password protection
    skip "Password protection validation not implemented" unless ProofAttachmentValidator.method_defined?(:validate_password_protection)

    # Create a mock password-protected PDF
    file_path = Rails.root.join("tmp", "protected.pdf")
    File.open(file_path, "w") do |f|
      f.write("Simulated password-protected PDF")
    end

    inbound_email = create_inbound_email_with_attachment(
      to: "proof@example.com",
      from: @constituent.email,
      subject: "Income Proof Submission",
      body: "Please find my income proof attached.",
      attachment_path: file_path,
      content_type: "application/pdf"
    )

    # Mock the validation to fail for password protection
    ProofAttachmentValidator.stub(:validate!, ->(attachment) {
      raise ProofAttachmentValidator::ValidationError, "File is password protected"
    }) do
      inbound_email.route
      assert_equal "bounced", inbound_email.status
    end

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end
end
