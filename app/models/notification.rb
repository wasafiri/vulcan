# frozen_string_literal: true

class Notification < ApplicationRecord
  belongs_to :recipient, class_name: 'User'
  belongs_to :actor, class_name: 'User', optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :recipient_id, presence: true
  validates :action, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :medical_certification_requests, -> { where(action: 'medical_certification_requested') }

  def mark_as_read!
    update(read_at: Time.current)
  end

  # Email status methods for medical certification requests
  def email_tracking?
    message_id.present?
  end

  def check_email_status!
    return unless email_tracking?

    UpdateEmailStatusJob.perform_later(id)
  end

  def delivery_status_badge_class
    return 'bg-gray-100 text-gray-600' unless email_tracking?

    case delivery_status
    when 'Delivered'
      'bg-green-100 text-green-800'
    when 'Opened'
      'bg-blue-100 text-blue-800'
    when 'error'
      'bg-red-100 text-red-800'
    else
      'bg-yellow-100 text-yellow-800'
    end
  end

  def email_error_message
    return nil unless delivery_status == 'error'

    metadata&.dig('error_message') || 'Unknown error'
  end

  def update_metadata!(key, value)
    new_metadata = metadata || {}
    new_metadata[key.to_s] = value
    update!(metadata: new_metadata)
  end

  # Generate a human-readable message for the notification by delegating to the NotificationComposer.
  # This ensures all message logic is centralized and consistent.
  def message
    @message ||= NotificationComposer.generate(action, notifiable, actor, metadata)
  end
end
