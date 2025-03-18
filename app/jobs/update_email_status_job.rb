class UpdateEmailStatusJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    notification = Notification.find_by(id: notification_id)
    return unless notification
    return unless notification.message_id.present?

    # Only process certification requests
    return unless notification.action == "medical_certification_requested" 

    begin
      status = PostmarkEmailTracker.fetch_status(notification.message_id)
      
      # Update notification with delivery status
      notification.update!(
        delivery_status: status[:status],
        delivered_at: status[:delivered_at],
        opened_at: status[:opened_at]
      )
      
      # Store open details in metadata
      if status[:open_details].present?
        current_metadata = notification.metadata || {}
        notification.update!(
          metadata: current_metadata.merge(
            email_details: status[:open_details]
          )
        )
      end
      
      # Schedule a follow-up check if not yet opened
      if status[:status] != 'error' && status[:opened_at].nil?
        self.class.set(wait: 24.hours).perform_later(notification_id)
      end
    rescue StandardError => e
      Rails.logger.error("Error updating email status for notification #{notification_id}: #{e.message}")
      notification.update!(
        delivery_status: 'error',
        metadata: notification.metadata.merge(
          error_message: e.message
        )
      )
    end
  end
end
