# frozen_string_literal: true

# Decorator for notifications to prevent unnecessary ActiveStorage eager loading
# when displaying notifications in views
class NotificationDecorator
  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  delegate :id, to: :notification

  delegate :read_at, to: :notification

  delegate :created_at, to: :notification

  delegate :action, to: :notification

  def email_tracking?
    notification.message_id.present?
  end

  delegate :delivery_status, to: :notification

  delegate :delivery_status_badge_class, to: :notification

  def email_error_message
    return nil unless delivery_status == 'error'

    notification.metadata&.dig('error_message') || 'Unknown error'
  end

  # Pass through method_missing to the original notification for methods we don't override
  def method_missing(method_name, *, &)
    if notification.respond_to?(method_name)
      notification.send(method_name, *, &)
    else
      super
    end
  end

  def respond_to_missing?(method_name, include_private = false)
    notification.respond_to?(method_name, include_private) || super
  end

  # Implementation of to_ary that avoids infinite recursion issues
  # when the decorator is used in array operations
  def to_ary
    nil # Return nil to avoid being treated as an array
  end
end
