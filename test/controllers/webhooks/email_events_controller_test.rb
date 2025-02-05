require "test_helper"

class Webhooks::EmailEventsControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Use application factory with medical provider
    @application = create(:application, :in_progress)
    @valid_payload = {
      event: "bounce",
      type: "permanent",
      email: @application.medical_provider_email,
      bounce: {
        type: "permanent",
        diagnostics: "Invalid recipient"
      }
    }
    # Use a test webhook secret
    @webhook_secret = "test_webhook_secret"
  end

  def test_accepts_valid_payload_with_correct_signature
    signature = compute_signature(@valid_payload.to_json)
    post webhooks_email_events_path,
      params: @valid_payload,
      headers: { "X-Webhook-Signature" => signature },
      as: :json
    assert_response :success
  end

  def test_rejects_invalid_signature
    post webhooks_email_events_path,
      params: @valid_payload,
      headers: { "X-Webhook-Signature" => "invalid" },
      as: :json
    assert_response :unauthorized
  end

  def test_rejects_incomplete_payload
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
