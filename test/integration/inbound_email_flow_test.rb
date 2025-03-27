# frozen_string_literal: true

require 'test_helper'

class InboundEmailFlowTest < ActionDispatch::IntegrationTest
  setup do
    # Set up a constituent with an active application
    @constituent = users(:constituent_john)
    @application = applications(:one)

    # Ensure application status is appropriate for accepting proofs
    @application.update!(status: 'in_progress')

    # Create sample email content that mimics a Postmark webhook payload
    @email_raw = <<~RAW_EMAIL
      From: #{@constituent.email}
      To: #{MatVulcan::InboundEmailConfig.inbound_email_address}
      Subject: Income Proof Submission
      MIME-Version: 1.0
      Content-Type: multipart/mixed; boundary="boundary-string"

      --boundary-string
      Content-Type: text/plain; charset="UTF-8"
      Content-Transfer-Encoding: quoted-printable

      Please find my income proof attached.

      --boundary-string
      Content-Type: application/pdf; name="proof.pdf"
      Content-Disposition: attachment; filename="proof.pdf"
      Content-Transfer-Encoding: base64

      U2FtcGxlIFBERiBjb250ZW50IGZvciB0ZXN0aW5n
      --boundary-string--
    RAW_EMAIL

    # Create Postmark webhook payload
    @postmark_payload = {
      From: @constituent.email,
      To: MatVulcan::InboundEmailConfig.inbound_email_address,
      Subject: 'Income Proof Submission',
      TextBody: 'Please find my income proof attached.',
      HtmlBody: '<p>Please find my income proof attached.</p>',
      Attachments: [
        {
          Name: 'proof.pdf',
          Content: Base64.strict_encode64('Sample PDF content for testing'),
          ContentType: 'application/pdf'
        }
      ],
      RawEmail: Base64.strict_encode64(@email_raw)
    }.to_json

    # Set inbound webhook password for ActionMailbox
    @original_password = ENV['RAILS_INBOUND_EMAIL_PASSWORD']
    ENV['RAILS_INBOUND_EMAIL_PASSWORD'] = 'test_password'

    # Store how many proofs and events exist before the test
    @initial_proof_count = @application.proofs.count
    @initial_event_count = Event.count
  end

  teardown do
    # Restore original environment variables
    ENV['RAILS_INBOUND_EMAIL_PASSWORD'] = @original_password
  end

  test 'processes inbound email from Postmark webhook' do
    # Simulate a Postmark webhook request
    post '/rails/action_mailbox/postmark/inbound_emails',
         params: @postmark_payload,
         headers: {
           'Content-Type' => 'application/json',
           'X-Request-Password' => 'test_password'
         }

    # Verify the webhook was accepted
    assert_response :success

    # Verify the proof was attached
    @application.reload
    assert_equal @initial_proof_count + 1, @application.proofs.count

    # Verify events were created
    assert_equal @initial_event_count + 2, Event.count

    # Verify the proof has the right attributes
    proof = @application.proofs.income.last
    assert_equal :email, proof.submission_method
    assert proof.metadata.key?('email_subject')
    assert proof.metadata.key?('inbound_email_id')
  end

  test 'rejects webhook with invalid password' do
    # Simulate a Postmark webhook request with wrong password
    post '/rails/action_mailbox/postmark/inbound_emails',
         params: @postmark_payload,
         headers: {
           'Content-Type' => 'application/json',
           'X-Request-Password' => 'wrong_password'
         }

    # Verify the webhook was rejected
    assert_response :unauthorized

    # Verify no proof was attached
    @application.reload
    assert_equal @initial_proof_count, @application.proofs.count

    # Verify no events were created
    assert_equal @initial_event_count, Event.count
  end
end
