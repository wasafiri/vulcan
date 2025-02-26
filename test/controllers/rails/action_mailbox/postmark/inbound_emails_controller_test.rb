require "test_helper"

class Rails::ActionMailbox::Postmark::InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @postmark_payload = {
      From: "constituent@example.com",
      To: "proof@example.com",
      Subject: "Income Proof Submission",
      TextBody: "Please find my income proof attached.",
      Attachments: [
        {
          Name: "income_proof.pdf",
          Content: Base64.encode64("This is a test PDF file"),
          ContentType: "application/pdf"
        }
      ],
      RawEmail: "From: constituent@example.com\r\nTo: proof@example.com\r\nSubject: Income Proof Submission\r\n\r\nPlease find my income proof attached."
    }.to_json

    # Set the ingress password for testing
    ActionMailbox::Base.ingress_password = "test_password"
  end

  test "can receive postmark webhook" do
    assert_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_postmark_inbound_emails_url,
           params: @postmark_payload,
           headers: {
             "Content-Type" => "application/json",
             "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("actionmailbox", "test_password")
           }

      assert_response :success
    end
  end

  test "rejects unauthorized requests" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_postmark_inbound_emails_url,
           params: @postmark_payload,
           headers: {
             "Content-Type" => "application/json",
             "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("actionmailbox", "wrong_password")
           }

      assert_response :unauthorized
    end
  end

  test "handles malformed json" do
    assert_no_difference -> { ActionMailbox::InboundEmail.count } do
      post rails_postmark_inbound_emails_url,
           params: "{ invalid json",
           headers: {
             "Content-Type" => "application/json",
             "Authorization" => ActionController::HttpAuthentication::Basic.encode_credentials("actionmailbox", "test_password")
           }

      assert_response :bad_request
    end
  end
end
