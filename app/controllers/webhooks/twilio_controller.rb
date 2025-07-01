# frozen_string_literal: true

module Webhooks
  # Controller for handling Twilio webhook callbacks
  class TwilioController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_twilio_signature, only: [:fax_status]

    # Handle fax status updates from Twilio
    def fax_status
      fax_sid = params[:FaxSid]
      status = params[:Status]

      Rails.logger.info "Received fax status update for SID: #{fax_sid}, Status: #{status}"

      # Find the associated notification or event record
      # This assumes you're storing the fax_sid in metadata when sending the fax
      notification = Notification.find_by("metadata->>'fax_sid' = ?", fax_sid)

      if notification.present?
        update_notification_status(notification, status)
        render json: { success: true, status: status }, status: :ok
      else
        # Log but don't fail if we can't find the notification
        Rails.logger.warn "Could not find notification for fax SID: #{fax_sid}"
        render json: { success: false, error: 'Notification not found' }, status: :ok
      end
    rescue StandardError => e
      Rails.logger.error "Error handling fax status update: #{e.message}"
      render json: { success: false, error: e.message }, status: :internal_server_error
    end

    private

    def verify_twilio_signature
      # Production implementations should verify the request is coming from Twilio
      # by checking the X-Twilio-Signature header against your auth token
      # This is skipped in development/test for simplicity
      return true unless Rails.env.production?

      # For production, uncomment and use the Twilio request validator
      # validator = Twilio::Security::RequestValidator.new(Rails.application.config.twilio[:auth_token])
      # signature = request.headers['X-Twilio-Signature']
      # url = request.original_url
      #
      # unless validator.validate(url, params, signature)
      #   Rails.logger.warn "Invalid Twilio signature for request to #{url}"
      #   render json: { error: 'Invalid signature' }, status: :forbidden
      #   return false
      # end

      true
    end

    def update_notification_status(notification, status)
      # Map Twilio fax status to our internal status
      internal_status = case status
                        when 'queued', 'processing', 'sending'
                          'sending'
                        when 'delivered'
                          'delivered'
                        when 'received'
                          'received'
                        when 'no-answer', 'busy', 'failed', 'canceled'
                          'failed'
                        else
                          'unknown'
                        end

      # Update notification metadata with latest status
      metadata = notification.metadata || {}
      metadata['fax_status'] = internal_status
      metadata['fax_status_updated_at'] = Time.current.iso8601
      metadata['fax_status_details'] = status

      notification.update!(
        metadata: metadata,
        delivery_status: internal_status == 'delivered' ? 'delivered' : 'failed'
      )

      # If the fax failed, you might want to trigger an email fallback
      # This depends on your application's requirements
      return unless %w[failed no-answer busy canceled].include?(status)

      Rails.logger.info "Fax delivery failed with status: #{status}, considering email fallback"
      # You could trigger an email here if needed
      # MedicalProviderMailer.certification_rejected(...).deliver_later
    end
  end
end
