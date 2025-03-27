# frozen_string_literal: true

require 'webhook_signature'

module Webhooks
  # Test-specific email events controller that inherits from our test base controller
  # This allows us to test webhook functionality without requiring authentication
  class TestEmailEventsController < TestBaseController
    # Inherit all functionality from the real controller, but use our test base controller
    # This allows us to bypass authentication and signature verification in tests

    # Override valid_payload? to handle our test cases with more robust validation
    def valid_payload?
      # Check if the payload is missing required fields
      return false if params[:email].blank?
      return false if params[:event].blank?
      return false if params[:type].blank?

      # Validate event-specific fields
      case params[:event]
      when 'bounce'
        # Validate bounce fields
        return false if params[:bounce].blank? || !params[:bounce].is_a?(ActionController::Parameters)
        return false if params[:bounce][:type].blank?
        return false if params[:bounce][:diagnostics].blank?
      when 'complaint'
        # Validate complaint fields
        return false if params[:complaint].blank? || !params[:complaint].is_a?(ActionController::Parameters)
        return false if params[:complaint][:type].blank?
        return false if params[:complaint][:feedback_id].blank?
      else
        # Unknown event type
        return false
      end

      # Log validation result for debugging
      webhook_debug("Payload validation passed for event: #{params[:event]}")
      true
    end

    private

    # Process the webhook event
    def process_event
      # Log the event processing
      webhook_debug("Processing event: #{params[:event]}")

      # Call the handler
      handler = EmailEventHandler.new(webhook_params)

      # Process the event and return the result
      begin
        result = handler.process
        webhook_debug("Event processing result: #{result}")
        result
      rescue StandardError => e
        # Log the error but don't raise it
        webhook_debug("Error processing event: #{e.message}")
        Rails.logger.error("Error processing webhook event: #{e.message}")
        false
      end
    end

    # Helper method for webhook debugging
    def webhook_debug(message)
      return unless ENV['DEBUG_WEBHOOKS'] == 'true'

      Rails.logger.debug "[WEBHOOK DEBUG] #{message}"
    end
  end
end
