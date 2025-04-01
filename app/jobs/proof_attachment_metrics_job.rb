# frozen_string_literal: true

# Generates daily metrics on proof attachment success/failure rates
# Scheduled via config/recurring.yml to run at midnight every day
class ProofAttachmentMetricsJob < ApplicationJob
  queue_as :low

  def perform
    # Calculate success rate for last 24 hours
    total = ProofSubmissionAudit.where('created_at > ?', 24.hours.ago).count
    failed = ProofSubmissionAudit.where('created_at > ?', 24.hours.ago)
                                 .where("metadata->>'success' = ?", 'false').count

    if total.positive?
      success_rate = ((total - failed) / total.to_f) * 100

      # Log metrics
      Rails.logger.info "Proof attachment 24h metrics: #{success_rate.round(2)}% success rate (#{failed}/#{total} failed)"

      # Alert if success rate drops below threshold
      if success_rate < 95 && failed > 5
        admins = User.where(type: 'Administrator')
        admins.each do |admin|
          Notification.create!(
            recipient: admin,
            action: 'attachment_failure_warning',
            metadata: {
              success_rate: success_rate.round(2),
              total: total,
              failed: failed,
              period: '24h'
            }
          )
        end
      end
    end

    # Calculate metrics by proof type
    %w[income residency].each do |proof_type|
      type_total = ProofSubmissionAudit.where('created_at > ?', 24.hours.ago)
                                       .where(proof_type: proof_type).count
      type_failed = ProofSubmissionAudit.where('created_at > ?', 24.hours.ago)
                                        .where(proof_type: proof_type)
                                        .where("metadata->>'success' = ?", 'false').count

      if type_total.positive?
        type_success_rate = ((type_total - type_failed) / type_total.to_f) * 100
        Rails.logger.info "#{proof_type.capitalize} proof 24h metrics: #{type_success_rate.round(2)}% success rate (#{type_failed}/#{type_total} failed)"
      end
    end

    # Calculate metrics by submission method
    %w[paper web].each do |method|
      method_total = ProofSubmissionAudit.where('created_at > ?', 24.hours.ago)
                                         .where(submission_method: method).count
      method_failed = ProofSubmissionAudit.where('created_at > ?', 24.hours.ago)
                                          .where(submission_method: method)
                                          .where("metadata->>'success' = ?", 'false').count

      if method_total.positive?
        method_success_rate = ((method_total - method_failed) / method_total.to_f) * 100
        Rails.logger.info "#{method.capitalize} submission 24h metrics: #{method_success_rate.round(2)}% success rate (#{method_failed}/#{method_total} failed)"
      end
    end
  end
end
