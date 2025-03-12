module Applications
  class MedicalCertificationService < BaseService
    attr_reader :application, :actor

    def initialize(application:, actor:)
      super()
      @application = application
      @actor = actor
    end

    def request_certification
      # Validate medical provider email
      return add_error("Medical provider email is required") unless application.medical_provider_email.present?

      # Get current time once to ensure consistency
      current_time = Time.current

      begin
        # Main updates in a transaction
        ApplicationRecord.transaction do
          update_certification_status(current_time)
          increment_request_count(current_time)
        end
        
        # Create notification for tracking
        notification = create_notification(current_time)
        
        # Send email with notification for tracking
        send_email(notification)
        
        true
      rescue StandardError => e
        log_error(e, "Application ID: #{application.id}")
        false
      end
    end

    private

    def update_certification_status(timestamp)
      # Use update_columns to bypass validations while maintaining audit trail
      application.update_columns(
        medical_certification_requested_at: timestamp,
        medical_certification_status: Application.medical_certification_statuses[:requested],
        updated_at: timestamp # Ensure timestamp is updated for audit purposes
      )
    end

    def increment_request_count(timestamp)
      new_count = (application.medical_certification_request_count || 0) + 1
      application.update_columns(
        medical_certification_request_count: new_count,
        updated_at: timestamp
      )
    end

    def create_notification(timestamp)
      # Check for existing notification with this request count
      request_count = application.medical_certification_request_count
      existing_notification = Notification.find_by(
        recipient: application.user,
        action: "medical_certification_requested",
        notifiable: application,
        metadata: { "request_count" => request_count }
      )
      
      if existing_notification
        # Log the attempt to create a duplicate
        Rails.logger.warn "Prevented duplicate notification for Application ##{application.id} request_count=#{request_count}"
        
        # Return the existing notification
        return existing_notification
      end
      
      # No duplicate found, create a new notification
      notification = Notification.create!(
        recipient: application.user,
        actor: actor,
        action: "medical_certification_requested",
        notifiable: application,
        metadata: {
          request_count: request_count,
          timestamp: timestamp.iso8601,
          provider: application.medical_provider_name,
          provider_email: application.medical_provider_email
        }
      )
      
      # Return the notification for use in email tracking
      notification
    rescue StandardError => e
      # Log but don't fail the process
      log_error(e, "Failed to create notification")
      nil
    end

    def send_email(notification)
      # Queue email delivery to background job instead of immediate delivery
      # This prevents email failures from blocking the request process
      MedicalCertificationEmailJob.perform_later(
        application_id: application.id,
        timestamp: Time.current.iso8601,
        notification_id: notification&.id
      )
    rescue StandardError => e
      # Still log the error if job enqueuing fails
      log_error(e, "Failed to enqueue email job")
      # We don't re-raise here to prevent job failures from stopping the process
    end
  end
end
