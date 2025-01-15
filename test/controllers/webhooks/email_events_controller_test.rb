# test/controllers/webhooks/email_events_controller_test.rb
require "test_helper"

class Webhooks::EmailEventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @application = create(:application)
    @valid_payload = {
      event: "bounce",
      type: "permanent",
      email: @application.medical_provider_email,
      bounce: {
        type: "permanent",
        diagnostics: "Invalid recipient"
      }
    }
    @webhook_secret = Rails.application.credentials.webhook_secret
  end

  test "accepts valid payload with correct signature" do
    signature = compute_signature(@valid_payload.to_json)

    post webhooks_email_events_path,
      params: @valid_payload,
      headers: { "X-Webhook-Signature" => signature },
      as: :json

    assert_response :success
  end

  test "rejects invalid signature" do
    post webhooks_email_events_path,
      params: @valid_payload,
      headers: { "X-Webhook-Signature" => "invalid" },
      as: :json

    assert_response :unauthorized
  end

  test "rejects incomplete payload" do
    invalid_payload = @valid_payload.except(:email)
    signature = compute_signature(invalid_payload.to_json)

    post webhooks_email_events_path,
      params: invalid_payload,
      headers: { "X-Webhook-Signature" => signature },
      as: :json

    assert_response :unprocessable_entity
  end

  private

  def compute_signature(payload)
    OpenSSL::HMAC.hexdigest(
      "sha256",
      @webhook_secret,
      payload
    )
  end
end
