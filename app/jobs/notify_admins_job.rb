# frozen_string_literal: true

class NotifyAdminsJob < ApplicationJob
  queue_as :default

  def perform(application)
    User.where(type: 'Users::Administrator').find_each do |admin|
      # Log the audit event
      AuditEventService.log(
        action: 'proof_needs_review_notification_sent',
        actor: application.user, # The user who submitted the proof is the actor
        auditable: application,
        metadata: {
          recipient_id: admin.id,
          proof_types: application.pending_proof_types # Assuming this method exists on Application
        }
      )

      # Send the notification
      NotificationService.create_and_deliver!(
        type: 'proof_needs_review',
        recipient: admin,
        actor: application.user,
        notifiable: application,
        channel: :email
      )
    end
  end
end
