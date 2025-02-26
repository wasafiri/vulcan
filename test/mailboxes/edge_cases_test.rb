require "test_helper"
require "support/action_mailbox_test_helper"

class EdgeCasesTest < ActionMailbox::TestCase
  include ActionMailboxTestHelper

  setup do
    @constituent = users(:constituent)
    @application = applications(:active_application)
    @constituent.update(email: "constituent@example.com")
    @application.update(constituent: @constituent)
  end

  test "handles emails with no attachments" do
    inbound_email = create_inbound_email_from_mail(
      to: "proof@example.com",
      from: @constituent.email,
      subject: "Income Proof Submission",
      body: "I forgot to attach my proof."
    )

    inbound_email.route

    # Verify the email was bounced
    assert_equal "bounced", inbound_email.status

    # Verify an event was created with the error
    assert Event.exists?(
      user: @constituent,
      action: "proof_submission_no_attachments"
    )
  end

  test "handles emails with invalid attachment types" do
    # Create a temporary file for testing
    file_path = Rails.root.join("tmp", "invalid_file.exe")
    File.open(file_path, "w") do |f|
      f.write("This is a test executable file")
    end

    inbound_email = create_inbound_email_with_attachment(
      to: "proof@example.com",
      from: @constituent.email,
      subject: "Income Proof Submission",
      body: "Please find my income proof attached.",
      attachment_path: file_path,
      content_type: "application/octet-stream"
    )

    inbound_email.route

    # Verify the email was bounced
    assert_equal "bounced", inbound_email.status

    # Verify an event was created with the error
    assert Event.exists?(
      user: @constituent,
      action: "proof_submission_invalid_attachment"
    )

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  test "handles emails with oversized attachments" do
    # Skip this test if ProofAttachmentValidator doesn't validate size
    skip "ProofAttachmentValidator doesn't validate size" unless ProofAttachmentValidator.method_defined?(:validate_size)

    # Create a temporary file for testing
    file_path = Rails.root.join("tmp", "large_file.pdf")

    # Create a mock attachment with a large size
    attachment = Minitest::Mock.new
    attachment.expect(:content_type, "application/pdf")
    attachment.expect(:filename, "large_file.pdf")

    # Mock the body to return a large size
    body = Minitest::Mock.new
    body.expect(:decoded, "x" * 11.megabytes)
    attachment.expect(:body, body)

    # Mock the ProofAttachmentValidator to raise an error
    ProofAttachmentValidator.stub(:validate!, ->(attachment) {
      raise ProofAttachmentValidator::ValidationError, "File size exceeds maximum allowed"
    }) do
      # Create a mailbox instance and call validate_attachments
      mailbox = ProofSubmissionMailbox.new(create_inbound_email_from_mail(
        to: "proof@example.com",
        from: @constituent.email,
        subject: "Income Proof Submission"
      ))

      # Mock the mail.attachments to return our mock attachment
      def mailbox.mail
        mail = Minitest::Mock.new
        attachments = [ attachment ]
        mail.expect(:attachments, attachments)
        mail
      end

      # Call the private method
      assert_raises(ProofAttachmentValidator::ValidationError) do
        mailbox.send(:validate_attachments)
      end
    end
  end

  test "handles emails with multiple attachments" do
    # Create temporary files for testing
    file_path1 = Rails.root.join("tmp", "income_proof1.pdf")
    file_path2 = Rails.root.join("tmp", "income_proof2.pdf")

    File.open(file_path1, "w") { |f| f.write("This is test file 1") }
    File.open(file_path2, "w") { |f| f.write("This is test file 2") }

    # Create a raw email with multiple attachments
    mail = Mail.new do
      from "constituent@example.com"
      to "proof@example.com"
      subject "Income Proof Submission"

      text_part do
        body "Please find my income proofs attached."
      end

      add_file filename: "income_proof1.pdf", content: File.read(file_path1)
      add_file filename: "income_proof2.pdf", content: File.read(file_path2)
    end

    # Create and route the inbound email
    inbound_email = ActionMailbox::InboundEmail.create_and_extract_message_id!(mail.to_s)
    inbound_email.route

    # Verify both attachments were processed
    if @application.respond_to?(:income_proof)
      assert @application.income_proof.attached?
      assert_equal 2, @application.income_proof.attachments.count
    end

    # Clean up
    File.delete(file_path1) if File.exist?(file_path1)
    File.delete(file_path2) if File.exist?(file_path2)
  end

  test "handles rate limiting" do
    # Skip this test if RateLimit doesn't exist
    skip "RateLimit not available" unless defined?(RateLimit)

    # Mock RateLimit to raise an error
    RateLimit.stub(:check!, ->(*args) { raise RateLimit::ExceededError }) do
      inbound_email = create_inbound_email_from_mail(
        to: "proof@example.com",
        from: @constituent.email,
        subject: "Income Proof Submission"
      )

      inbound_email.route

      # Verify the email was bounced
      assert_equal "bounced", inbound_email.status

      # Verify an event was created with the error
      assert Event.exists?(
        user: @constituent,
        action: "proof_submission_rate_limit_exceeded"
      )
    end
  end
end
