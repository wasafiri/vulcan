class Notification < ApplicationRecord
  belongs_to :recipient, class_name: 'User'
  belongs_to :actor, class_name: 'User', optional: true
  belongs_to :notifiable, polymorphic: true, optional: true

  validates :recipient_id, :action, presence: true

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
  
  # Generate a human-readable message for the notification based on its action and context
  def message
    case action
    when 'medical_certification_requested'
      "Medical certification requested for application ##{notifiable_id}"
    when 'medical_certification_received'
      "Medical certification received for application ##{notifiable_id}"
    when 'medical_certification_approved'
      "Medical certification approved for application ##{notifiable_id}"
    when 'medical_certification_rejected'
      "Medical certification rejected for application ##{notifiable_id}"
    when 'proof_approved'
      "Proof approved for application ##{notifiable_id}"
    when 'proof_rejected'
      "Proof rejected for application ##{notifiable_id}"
    when 'documents_requested'
      "Documents requested for application ##{notifiable_id}"
    when 'review_requested'
      "Review requested for application ##{notifiable_id}"
    when 'trainer_assigned'
      trainer_name = actor&.full_name || "A trainer"
      application = notifiable
      constituent_name = application&.constituent_full_name || "a constituent"
      
      # Get associated training session if it exists
      training_session = application&.training_sessions&.where(trainer_id: actor&.id)&.last
      status_info = training_session ? " (#{training_session.status.humanize})" : ""
      
      "#{trainer_name} assigned to train #{constituent_name} for Application ##{notifiable_id}#{status_info}"
    else
      # Default fallback using humanized action
      "#{action.humanize} notification"
    end
  end
end
