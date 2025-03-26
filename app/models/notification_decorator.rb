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
  
  # Generate message without accessing association objects that might trigger eager loading
  def message
    case notification.action
    when 'medical_certification_requested'
      "Medical certification requested for application ##{notification.notifiable_id}"
    when 'medical_certification_received'
      "Medical certification received for application ##{notification.notifiable_id}"
    when 'medical_certification_approved'
      "Medical certification approved for application ##{notification.notifiable_id}"
    when 'medical_certification_rejected'
      "Medical certification rejected for application ##{notification.notifiable_id}"
    when 'proof_approved'
      "Proof approved for application ##{notification.notifiable_id}"
    when 'proof_rejected'
      "Proof rejected for application ##{notification.notifiable_id}"
    when 'documents_requested'
      "Documents requested for application ##{notification.notifiable_id}"
    when 'review_requested'
      "Review requested for application ##{notification.notifiable_id}"
    when 'trainer_assigned'
      "Trainer assigned for Application ##{notification.notifiable_id}"
    else
      # Default fallback using humanized action
      "#{notification.action.humanize} notification"
    end
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
end
