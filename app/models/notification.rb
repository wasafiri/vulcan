# frozen_string_literal: true

class Notification < ApplicationRecord
  attr_accessor :delivery_successful

  # Suffix: true generates methods like `delivered_status?` and scopes like `delivered_status`.
  enum :delivery_status, { delivered: 'delivered', opened: 'opened', error: 'error' }, suffix: true

  belongs_to :recipient, class_name: 'User'
  belongs_to :actor, class_name: 'User', optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :action, presence: true

  scope :unread_notifications, -> { where(read_at: nil) }
  scope :read_notifications, -> { where.not(read_at: nil) }
  scope :medical_certification_requests, -> { where(action: 'medical_certification_requested') }

  def mark_as_read!
    update!(read_at: Time.current)
  end

  # Email status methods for medical certification requests.
  # These methods depend on the `message_id` column in the `notifications` table
  # and the existence of an `UpdateEmailStatusJob`.
  def email_tracking?
    message_id.present?
  end

  def check_email_status!
    return unless email_tracking?

    UpdateEmailStatusJob.perform_later(id)
  end

  def email_error_message
    return nil unless delivery_status == 'error'
    return 'Unknown error' unless metadata.is_a?(Hash)

    metadata.fetch('delivery_error', {}).fetch('message', 'Unknown error')
  end

  def update_metadata!(key, value)
    with_lock do
      new_metadata = metadata || {}
      new_metadata[key.to_s] = value
      update!(metadata: new_metadata)
    end
  end

  # Generate a human-readable message for the notification by delegating to the NotificationComposer.
  # This ensures all message logic is centralized and consistent.
  def message
    NotificationComposer.generate(action, notifiable, actor, metadata)
  end
end
