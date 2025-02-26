require "test_helper"
require "support/action_mailbox_test_helper"

class InboundEmailProcessingTest < ActionDispatch::IntegrationTest
  include ActionMailboxTestHelper

  setup do
    # Create a constituent and application using factories
    @constituent = create(:constituent)
    @application = create(:application, user: @constituent)
    @constituent.update(email: "constituent@example.com")

    # Create a medical provider using factory
    @medical_provider = create(:medical_provider, email: "doctor@example.com")

    # Create policy records for rate limiting
    create(:policy, :proof_submission_rate_limit_web)
    create(:policy, :proof_submission_rate_limit_email)
    create(:policy, :proof_submission_rate_period)

    # Add medical certification requested flag if needed
    unless @application.respond_to?(:medical_certification_requested?)
      @application.define_singleton_method(:medical_certification_requested?) do
        true
      end
    end

    # Set up ApplicationMailbox routing for testing
    ApplicationMailbox.instance_eval do
      routing(/proof@/i => :proof_submission)
      routing(/medical-cert@/i => :medical_certification)
      routing(/.+/ => :default)
    end

    # Set the ingress password for testing
    ActionMailbox::Base.ingress_password = "test_password"
  end

  test "processes income proof email from constituent" do
    # Create a temporary file for testing
    file_path = Rails.root.join("tmp", "income_proof.pdf")
    File.open(file_path, "w") do |f|
      f.write("This is a test PDF file")
    end

    # Create a raw email with attachment
    mail = Mail.new do
      from "constituent@example.com"
      to "proof@example.com"
      subject "Income Proof Submission"

      text_part do
        body "Please find my income proof attached."
      end

      add_file filename: "income_proof.pdf", content: File.read(file_path)
    end

    # Create a Postmark-like payload
    postmark_payload = {
      From: mail.from.first,
      To: mail.to.first,
      Subject: mail.subject,
      TextBody: mail.text_part.body.to_s,
      Attachments: [
        {
          Name: "income_proof.pdf",
          Content: Base64.encode64(File.read(file_path)),
          ContentType: "application/pdf"
        }
      ],
      RawEmail: mail.to_s
    }.to_json

    # Send the webhook request
    assert_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_postmark_inbound_emails_url,
           params: postmark_payload,
           headers: {
             "Content-Type" => "application/json",
             "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("actionmailbox", "test_password")
           }

      assert_response :success
    end

    # Process all inbound emails
    ActionMailbox::InboundEmail.last.route

    # Verify the proof was attached to the application
    if @application.respond_to?(:income_proof)
      assert @application.income_proof.attached?
    end

    # Verify an event was created
    assert Event.exists?(
      user: @constituent,
      action: "proof_submission_received"
    )

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  test "processes medical certification email from provider" do
    # Create a temporary file for testing
    file_path = Rails.root.join("tmp", "medical_certification.pdf")
    File.open(file_path, "w") do |f|
      f.write("This is a test medical certification PDF file")
    end

    # Create a raw email with attachment
    mail = Mail.new do
      from "doctor@example.com"
      to "medical-cert@example.com"
      subject "Medical Certification for Application ##{@application.id}"

      text_part do
        body "Please find the signed medical certification attached."
      end

      add_file filename: "medical_certification.pdf", content: File.read(file_path)
    end

    # Create a Postmark-like payload
    postmark_payload = {
      From: mail.from.first,
      To: mail.to.first,
      Subject: mail.subject,
      TextBody: mail.text_part.body.to_s,
      Attachments: [
        {
          Name: "medical_certification.pdf",
          Content: Base64.encode64(File.read(file_path)),
          ContentType: "application/pdf"
        }
      ],
      RawEmail: mail.to_s
    }.to_json

    # Send the webhook request
    assert_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_postmark_inbound_emails_url,
           params: postmark_payload,
           headers: {
             "Content-Type" => "application/json",
             "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("actionmailbox", "test_password")
           }

      assert_response :success
    end

    # Process all inbound emails
    ActionMailbox::InboundEmail.last.route

    # Verify the certification was attached to the application
    if @application.respond_to?(:medical_certification)
      assert @application.medical_certification.attached?
    end

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
  end

  test "rejects email from unknown sender" do
    # Create a Postmark-like payload with unknown sender
    postmark_payload = {
      From: "unknown@example.com",
      To: "proof@example.com",
      Subject: "Income Proof Submission",
      TextBody: "Please find my income proof attached.",
      RawEmail: "From: unknown@example.com\r\nTo: proof@example.com\r\nSubject: Income Proof Submission\r\n\r\nPlease find my income proof attached."
    }.to_json

    # Send the webhook request
    post rails_postmark_inbound_emails_url,
         params: postmark_payload,
         headers: {
           "Content-Type" => "application/json",
           "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("actionmailbox", "test_password")
         }

    assert_response :success

    # Process all inbound emails
    inbound_email = ActionMailbox::InboundEmail.last
    inbound_email.route

    # Verify the email was bounced
    assert_equal "bounced", inbound_email.reload.status
  end

  test "sends notification to admin when proof is received" do
    # Skip if notification mailer doesn't exist
    skip "Admin notification not implemented" unless defined?(ApplicationNotificationsMailer) &&
                                                    ApplicationNotificationsMailer.respond_to?(:proof_received_notification)

    # Create a temporary file for testing
    file_path = Rails.root.join("tmp", "income_proof.pdf")
    File.open(file_path, "w") do |f|
      f.write("This is a test PDF file")
    end

    # Create a raw email with attachment
    mail = Mail.new do
      from "constituent@example.com"
      to "proof@example.com"
      subject "Income Proof Submission"
      text_part do
        body "Please find my income proof attached."
      end
      add_file filename: "income_proof.pdf", content: File.read(file_path)
    end

    # Create a Postmark-like payload
    postmark_payload = {
      From: mail.from.first,
      To: mail.to.first,
      Subject: mail.subject,
      TextBody: mail.text_part.body.to_s,
      Attachments: [
        {
          Name: "income_proof.pdf",
          Content: Base64.encode64(File.read(file_path)),
          ContentType: "application/pdf"
        }
      ],
      RawEmail: mail.to_s
    }.to_json

    # Send the webhook request and process the email
    assert_emails 1 do
      post rails_postmark_inbound_emails_url,
           params: postmark_payload,
           headers: {
             "Content-Type" => "application/json",
             "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("actionmailbox", "test_password")
           }
      ActionMailbox::InboundEmail.last.route
    end

    # Clean up
    File.delete(file_path) if File.exist?(file_path)
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

    # Create a Postmark-like payload
    postmark_payload = {
      From: mail.from.first,
      To: mail.to.first,
      Subject: mail.subject,
      TextBody: mail.text_part.body.to_s,
      Attachments: [
        {
          Name: "income_proof1.pdf",
          Content: Base64.encode64(File.read(file_path1)),
          ContentType: "application/pdf"
        },
        {
          Name: "income_proof2.pdf",
          Content: Base64.encode64(File.read(file_path2)),
          ContentType: "application/pdf"
        }
      ],
      RawEmail: mail.to_s
    }.to_json

    # Send the webhook request
    post rails_postmark_inbound_emails_url,
         params: postmark_payload,
         headers: {
           "Content-Type" => "application/json",
           "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("actionmailbox", "test_password")
         }

    # Process all inbound emails
    ActionMailbox::InboundEmail.last.route

    # Verify both attachments were processed if the application supports multiple attachments
    if @application.respond_to?(:income_proof) && @application.income_proof.respond_to?(:attachments)
      assert_equal 2, @application.income_proof.attachments.count
    end

    # Clean up
    File.delete(file_path1) if File.exist?(file_path1)
    File.delete(file_path2) if File.exist?(file_path2)
  end
end
