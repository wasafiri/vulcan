# frozen_string_literal: true

require 'webhook_signature'

module Webhooks
  # Test-specific base controller that overrides authentication and signature verification
  # This allows us to test webhook functionality without requiring authentication
  class TestBaseController < BaseController
    # Skip authentication for tests
    skip_before_action :sign_in, raise: false

    # Override the verify_webhook_signature method to use our test secret
    def verify_webhook_signature
      signature = request.headers['X-Webhook-Signature']

      # Log the signature for debugging
      webhook_debug("Verifying signature: #{signature}")

      # Return unauthorized if signature is missing or invalid
      if signature.nil? || signature == 'invalid'
        webhook_debug("Signature verification failed: #{signature.nil? ? 'missing' : 'invalid'}")
        head :unauthorized
        return false
      end

      # For testing, we don't actually verify the signature against the payload
      # We just check that it's present and not "invalid"
      webhook_debug('Signature verification passed')
      true
    end

    private

    # Helper method for webhook debugging
    def webhook_debug(message)
      return unless ENV['DEBUG_WEBHOOKS'] == 'true'

      Rails.logger.debug { "[WEBHOOK DEBUG] #{message}" }
    end
  end
end
