# frozen_string_literal: true

class MedicalCertificationEmailJob < ApplicationJob
  queue_as :default
  retry_on Net::SMTPError, wait: :exponentially_longer, attempts: 3

  def perform(application_id:, timestamp:, notification_id: nil)
    Rails.logger.info "Processing medical certification email for application #{application_id}"

    application = Application.find(application_id)

    # Find or create a notification for tracking
    notification = if notification_id
                     Notification.find_by(id: notification_id)
                   else
                     # Look for an existing notification that might have been created
                     existing = Notification.medical_certification_requests
                                            .where(notifiable: application)
                                            .where('created_at > ?', 1.minute.ago)
                                            .order(created_at: :desc)
                                            .first

                     # Use the existing notification or create a new one if needed
                     existing || create_notification(application, timestamp)
                   end

    # Send email with notification for tracking - updated to match new method signature
    MedicalProviderMailer.request_certification(application, timestamp, notification&.id).deliver_now

    Rails.logger.info "Successfully sent medical certification email for application #{application_id}"
  rescue StandardError => e
    Rails.logger.error "Failed to send certification email for application #{application_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Update notification with error if we have one
    if defined?(notification) && notification.present?
      notification.update_metadata!('error_message', e.message)
      notification.update(delivery_status: 'error')
    end

    # Still raise to trigger retry mechanism
    raise
  end

  private

  def create_notification(application, timestamp)
    recipient = User.find_by(role: 'admin') || User.first # Default recipient - ideally admins
    actor = begin
      Current.user
    rescue StandardError
      nil
    end

    Notification.create!(
      recipient: recipient,
      actor: actor,
      action: 'medical_certification_requested',
      notifiable: application,
      metadata: {
        timestamp: timestamp,
        provider: application.medical_provider_name,
        provider_email: application.medical_provider_email
      }
    )
  end
end
