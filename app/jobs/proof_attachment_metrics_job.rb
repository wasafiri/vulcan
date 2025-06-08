# frozen_string_literal: true

# Generates daily metrics on proof attachment success/failure rates
# Scheduled via config/recurring.yml to run at midnight every day
class ProofAttachmentMetricsJob < ApplicationJob
  queue_as :low

  def perform
    # Calculate success rate for last 24 hours
    # Query events with action ending in '_proof_submitted'
    recent_proof_submissions = Event.where("action LIKE '%_proof_submitted'")
                                    .where('created_at > ?', 24.hours.ago)

    total = recent_proof_submissions.count
    failed = recent_proof_submissions.where("metadata->>'success' = ?", 'false').count

    if total.positive?
      success_rate = ((total - failed) / total.to_f) * 100

      # Log metrics
      Rails.logger.info "Proof attachment 24h metrics: #{success_rate.round(2)}% success rate (#{failed}/#{total} failed)"

      # Alert if success rate drops below threshold
      if success_rate < 95 && failed > 5
        admins = User.where(type: 'Administrator')
        admins.each do |admin|
          # Log the audit event for the warning
          AuditEventService.log(
            action: 'attachment_failure_warning',
            actor: User.system_user, # System-generated event
            auditable: nil, # Not tied to a specific record
            metadata: {
              success_rate: success_rate.round(2),
              total: total,
              failed: failed,
              period: '24h'
            }
          )

          # Send the notification
          NotificationService.create_and_deliver!(
            type: 'attachment_failure_warning',
            recipient: admin,
            actor: User.system_user, # System-generated notification
            notifiable: nil, # Not tied to a specific record
            metadata: {
              success_rate: success_rate.round(2),
              total: total,
              failed: failed,
              period: '24h'
            },
            channel: :email
          )
        end
      end
    end

    # Calculate metrics by proof type
    %w[income residency].each do |proof_type|
      type_total = recent_proof_submissions.where("metadata->>'proof_type' = ?", proof_type).count
      type_failed = recent_proof_submissions.where("metadata->>'proof_type' = ?", proof_type)
                                            .where("metadata->>'success' = ?", 'false').count

      if type_total.positive?
        type_success_rate = ((type_total - type_failed) / type_total.to_f) * 100
        Rails.logger.info "#{proof_type.capitalize} proof 24h metrics: #{type_success_rate.round(2)}% success rate (#{type_failed}/#{type_total} failed)"
      end
    end

    # Calculate metrics by submission method
    %w[paper web].each do |method|
      method_total = recent_proof_submissions.where("metadata->>'submission_method' = ?", method).count
      method_failed = recent_proof_submissions.where("metadata->>'submission_method' = ?", method)
                                              .where("metadata->>'success' = ?", 'false').count

      if method_total.positive?
        method_success_rate = ((method_total - method_failed) / method_total.to_f) * 100
        Rails.logger.info "#{method.capitalize} submission 24h metrics: #{method_success_rate.round(2)}% success rate (#{method_failed}/#{method_total} failed)"
      end
    end
  end
end
