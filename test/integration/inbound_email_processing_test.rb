require "test_helper"
require "support/action_mailbox_test_helper"

class InboundEmailProcessingTest < ActionDispatch::IntegrationTest
  include ActionMailboxTestHelper

  setup do
    @constituent = users(:constituent)
    @application = applications(:active_application)
    @constituent.update(email: "constituent@example.com")
    @application.update(constituent: @constituent)

    # Create a medical provider if the model exists
    if defined?(MedicalProvider)
      @medical_provider = MedicalProvider.create!(
        name: "Dr. Test",
        email: "doctor@example.com"
      )

      # Add medical certification requested flag if needed
      unless @application.respond_to?(:medical_certification_requested?)
        @application.define_singleton_method(:medical_certification_requested?) do
          true
        end
      end
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
    skip "Medical provider model not available" unless defined?(MedicalProvider)

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
end
