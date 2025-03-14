# frozen_string_literal: true

# Service to handle proof attachments with consistent transaction handling and telemetry
class ProofAttachmentService
  def self.attach_proof(application:, proof_type:, blob_or_file:, status: :not_reviewed, admin: nil, metadata: {})
    start_time = Time.current
    result = { success: false, error: nil, duration_ms: 0 }
    
    begin
      # Single transaction pattern (like constituent portal)
      application.transaction do
        # Attach the proof
        application.send("#{proof_type}_proof").attach(blob_or_file)
        
        # Update status
        status_attrs = {"#{proof_type}_proof_status" => status}
        status_attrs[:needs_review_since] = Time.current if status == :not_reviewed
        application.update!(status_attrs)
      end
      
      # Create audit record for tracking and metrics
      ProofSubmissionAudit.create!(
        application: application,
        user: admin || application.user,
        proof_type: proof_type,
        submission_method: admin ? :paper : :web,
        ip_address: metadata[:ip_address] || '0.0.0.0',
        metadata: metadata.merge(
          success: true,
          status: status,
          has_attachment: application.send("#{proof_type}_proof").attached?,
          blob_id: application.send("#{proof_type}_proof").blob&.id
        )
      )
      
      result[:success] = true
      application.reload
    rescue => e
      # Track failure with detailed information
      record_failure(application, proof_type, e, admin, metadata)
      result[:error] = e
    ensure
      result[:duration_ms] = ((Time.current - start_time) * 1000).round
      record_metrics(result, proof_type, status)
    end
    
    result
  end
  
  def self.reject_proof_without_attachment(application:, proof_type:, admin:, reason: 'other', notes: nil, metadata: {})
    # Delegate to the existing model method that works
    start_time = Time.current
    result = { success: false, error: nil, duration_ms: 0 }
    
    begin
      # Use the existing method that's been verified to work
      success = application.reject_proof_without_attachment!(
        proof_type, 
        admin: admin,
        reason: reason,
        notes: notes || "Rejected during paper application submission"
      )
      
      if success
        # Create audit record for tracking and metrics
        ProofSubmissionAudit.create!(
          application: application,
          user: admin,
          proof_type: proof_type,
          submission_method: :paper,
          ip_address: metadata[:ip_address] || '0.0.0.0',
          metadata: metadata.merge(
            success: true,
            status: :rejected,
            has_attachment: false,
            rejection_reason: reason
          )
        )
      end
      
      result[:success] = success
    rescue => e
      record_failure(application, proof_type, e, admin, metadata)
      result[:error] = e
    ensure
      result[:duration_ms] = ((Time.current - start_time) * 1000).round
      record_metrics(result, proof_type, :rejected)
    end
    
    result
  end
  
  private
  
  def self.record_failure(application, proof_type, error, admin, metadata)
    Rails.logger.error "Proof attachment error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    # Record the failure for metrics and monitoring
    ProofSubmissionAudit.create!(
      application: application,
      user: admin || application.user,
      proof_type: proof_type,
      submission_method: admin ? :paper : :web,
      ip_address: metadata[:ip_address] || '0.0.0.0',
      metadata: metadata.merge(
        success: false,
        error_class: error.class.name,
        error_message: error.message,
        error_backtrace: error.backtrace.first(5)
      )
    ) rescue nil  # Don't let audit failures affect the main flow
    
    # Report to error tracking service if available
    if defined?(Honeybadger)
      Honeybadger.notify(error, 
        context: {
          application_id: application.id,
          proof_type: proof_type,
          admin_id: admin&.id,
          metadata: metadata
        }
      )
    end
  rescue => e
    # Last resort logging if even the failure tracking fails
    Rails.logger.error "Failed to record proof failure: #{e.message}"
  end
  
  def self.record_metrics(result, proof_type, status)
    # Basic logging
    if result[:success]
      Rails.logger.info "Proof #{proof_type} #{status} completed in #{result[:duration_ms]}ms"
    else
      Rails.logger.error "Proof #{proof_type} #{status} failed in #{result[:duration_ms]}ms: #{result[:error]&.message}"
    end
    
    # Add integration with monitoring tools
    # This is a placeholder - we'd integrate with whatever monitoring system is in use
    # For example, with Datadog:
    if defined?(Datadog)
      tags = ["proof_type:#{proof_type}", "status:#{status}", "success:#{result[:success]}"]
      Datadog.increment('proof_attachments.count', tags: tags)
      Datadog.timing('proof_attachments.duration', result[:duration_ms], tags: tags)
    end
  rescue => e
    # Don't let metrics recording failures impact the actual operation
    Rails.logger.error "Failed to record proof metrics: #{e.message}"
  end
end
