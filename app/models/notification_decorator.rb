# frozen_string_literal: true

# Decorator for notifications to prevent unnecessary ActiveStorage eager loading
# when displaying notifications in views
class NotificationDecorator
  attr_reader :notification

  def initialize(notification)
    @notification = notification
  end

  def id
    notification.id
  end

  def read_at
    notification.read_at
  end

  def created_at
    notification.created_at
  end

  def action
    notification.action
  end

  def email_tracking?
    notification.message_id.present?
  end

  def delivery_status
    notification.delivery_status
  end

  def delivery_status_badge_class
    notification.delivery_status_badge_class
  end

  def email_error_message
    return nil unless delivery_status == 'error'

    notification.metadata&.dig('error_message') || 'Unknown error'
  end

  # Pass through method_missing to the original notification for methods we don't override
  def method_missing(method_name, *args, &block)
    if notification.respond_to?(method_name)
      notification.send(method_name, *args, &block)
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
