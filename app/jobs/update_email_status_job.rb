# frozen_string_literal: true

# Job for tracking and updating email delivery status for notifications.
# Handles medical certification request notifications by
# fetching status from Postmark and updating notification records.
class UpdateEmailStatusJob < ApplicationJob
  queue_as :default

  def perform(notification_id)
    notification = find_and_validate_notification(notification_id)
    return unless notification

    begin
      status = PostmarkEmailTracker.fetch_status(notification.message_id)
      update_notification_status(notification, status)
      update_notification_metadata(notification, status)
      schedule_follow_up_if_needed(notification_id, status)
    rescue StandardError => e
      handle_error(notification, notification_id, e)
    end
  end

  private

  def find_and_validate_notification(notification_id)
    notification = Notification.find_by(id: notification_id)
    return unless notification
    return if notification.message_id.blank?
    return unless notification.action == 'medical_certification_requested'

    notification
  end

  def update_notification_status(notification, status)
    notification.update!(
      delivery_status: status[:status],
      delivered_at: status[:delivered_at],
      opened_at: status[:opened_at]
    )
  end

  def update_notification_metadata(notification, status)
    return if status[:open_details].blank?

    current_metadata = notification.metadata || {}
    notification.update!(
      metadata: current_metadata.merge(
        email_details: status[:open_details]
      )
    )
  end

  def schedule_follow_up_if_needed(notification_id, status)
    return if status[:status] == 'error' || status[:opened_at].present?

    self.class.set(wait: 24.hours).perform_later(notification_id)
  end

  def handle_error(notification, notification_id, error)
    Rails.logger.error("Error updating email status for notification #{notification_id}: #{error.message}")
    notification.update!(
      delivery_status: 'error',
      metadata: notification.metadata.merge(
        error_message: error.message
      )
    )
  end
end
