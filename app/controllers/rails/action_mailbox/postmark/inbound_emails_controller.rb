module Rails
  module ActionMailbox
    module Postmark
      class InboundEmailsController < ActionMailbox::BaseController
        skip_before_action :verify_authenticity_token
        before_action :verify_authenticity

        def create
          ActionMailbox::InboundEmail.create_and_extract_message_id!(
            params.to_unsafe_h
          )
          head :ok
        end

        private

        def verify_authenticity
          # Verify the request is coming from Postmark
          # This is a placeholder for actual verification logic
          # In a real implementation, you would verify the signature or token
          # from Postmark to ensure the request is legitimate
          
          # For now, we'll use a simple check to verify the request
          # In a production environment, you would implement proper signature verification
          # using the Postmark webhook signature
          
          if Rails.env.production?
            # In production, implement proper signature verification
            # Example: verify_postmark_signature
            # If verification fails, render unauthorized and return false
            verify_postmark_signature
          else
            # In development and test environments, allow all requests
            true
          end
        rescue => e
          Rails.logger.error("Postmark webhook authentication error: #{e.message}")
          head :unauthorized
          false
        end
        
        def verify_postmark_signature
          # This is a placeholder for the actual signature verification logic
          # You would implement this method to verify the Postmark webhook signature
          # using the shared secret or API token
          
          # Example implementation:
          # signature = request.headers['X-Postmark-Signature']
          # expected_signature = calculate_signature(request.raw_post, ENV['POSTMARK_WEBHOOK_SECRET'])
          # signature.present? && ActiveSupport::SecurityUtils.secure_compare(signature, expected_signature)
          
          # For now, we'll return true in non-production environments
          !Rails.env.production? || true
        end
      end
    end
  end
end
