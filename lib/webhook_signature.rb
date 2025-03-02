# Shared module for computing webhook signatures
# This ensures consistent signature computation between production and tests
module WebhookSignature
  # Compute an HMAC signature for a webhook payload
  # @param payload [String] The raw payload to sign
  # @param secret [String, nil] The secret to use for signing (defaults to Rails credentials)
  # @return [String] The computed HMAC signature
  def self.compute_signature(payload, secret = nil)
    # Use the provided secret or fall back to the Rails credentials
    secret ||= Rails.application.credentials.webhook_secret

    # Compute the HMAC signature using SHA-256
    OpenSSL::HMAC.hexdigest("sha256", secret, payload)
  end
end
