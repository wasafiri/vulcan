# frozen_string_literal: true

# Service to handle proof attachments with consistent transaction handling and telemetry
#
# This service is the central point for all proof attachment operations in the application.
# It's used by both the constituent portal and paper application workflows to ensure
# consistency in how attachments are processed, validated, and tracked.
#
# Key responsibilities:
# 1. Provide a unified interface for attaching proofs for both paper and online submissions
# 2. Handle blob/file conversion for different input types
# 3. Maintain audit records and metrics for all attachment operations
# 4. Provide consistent error handling and diagnostics
#
# This is the single source of truth for attachment operations to avoid inconsistencies
# between different submission paths.
class ProofAttachmentService
  # Attaches a proof document to an application
  #
  # This is the central method used by both constituent portal and paper application
  # workflows to attach proof documents. It handles different input types, manages
  # transactions, and provides consistent logging and metrics.
  #
  # @param args [Hash] A hash containing the arguments for attachment:
  #   - :application [Application] (required) The application to attach the proof to.
  #   - :proof_type [Symbol] (required) The type of proof (:income or :residency).
  #   - :blob_or_file [ActiveStorage::Blob, String, ActionDispatch::Http::UploadedFile] (required) The file to attach.
  #   - :submission_method [Symbol] (required) The method of submission (:paper, :web, :email, etc.).
  #   - :status [Symbol] (optional, default: :not_reviewed) The status to set for the proof.
  #   - :admin [User] (optional) The admin user if this is an admin action.
  #   - :metadata [Hash] (optional) Additional metadata to store with the attachment audit.
  #
  # @return [Hash] Result hash with :success, :error, and :duration_ms keys
  def self.attach_proof(args)
    params = {
      status: :not_reviewed,
      admin: nil,
      metadata: {},
      skip_audit_events: false
    }.merge(args)

    context = {
      application: params.fetch(:application),
      proof_type: params.fetch(:proof_type),
      admin: params.fetch(:admin),
      submission_method: params.fetch(:submission_method),
      metadata: params.fetch(:metadata),
      status: params.fetch(:status)
    }

    with_service_flow(context) do |result|
      perform_attachment_flow(result, params)
    end
  end

  # Rejects a proof without requiring a file attachment
  #
  # This method is used to explicitly reject proof submissions, typically when an admin
  # is reviewing a paper application and decides not to accept the proof document.
  # It maintains the same audit trail and metrics as the attachment flow.
  #
  # @param application [Application] The application to reject the proof for
  # @param proof_type [Symbol] The type of proof (:income or :residency)
  # @param admin [User] The admin user performing the rejection (required)
  # @param submission_method [Symbol] The method of submission (:paper, :web, :email, etc.)
  # @param rejection_details [Hash] Details about the rejection, including:
  #   - :reason [String] The reason for rejection (e.g., 'unclear', 'incomplete', 'other')
  #   - :notes [String, nil] Optional notes explaining the rejection
  #   - :metadata [Hash] Additional metadata to store with the rejection audit
  #
  # @return [Hash] Result hash with :success, :error, and :duration_ms keys
  def self.reject_proof_without_attachment(application:, proof_type:, admin:, submission_method:, **rejection_details)
    context = {
      application: application, proof_type: proof_type, admin: admin,
      submission_method: submission_method, metadata: rejection_details.fetch(:metadata, {}),
      status: :rejected
    }

    with_service_flow(context) do |result|
      success = perform_rejection(application: application, proof_type: proof_type, admin: admin,
                                  submission_method: submission_method, rejection_details: rejection_details)

      if success
        log_rejection_events(application: application, proof_type: proof_type, admin: admin,
                             submission_method: submission_method, rejection_details: rejection_details)
      end

      result[:success] = success
    end
  end

  def self.record_failure(error, context)
    log_error(error)
    log_failure_audit_event(error, context)
  rescue StandardError => e
    # Last resort logging if even the failure tracking fails
    Rails.logger.error "Failed to record proof failure: #{e.message}"
  end

  def self.record_metrics(result, proof_type, status)
    record_basic_logging(result, proof_type, status)
    context = build_context(result, proof_type, status)
    record_datadog_metrics(result, context, proof_type, status)
    Rails.logger.info("METRICS: proof_attachment #{context.to_json}")
  rescue StandardError => e
    Rails.logger.error "Failed to record proof metrics: #{e.message}"
  end

  def self.record_basic_logging(result, proof_type, status)
    if result[:success]
      Rails.logger.info "Proof #{proof_type} #{status} completed in #{result[:duration_ms]}ms"
    else
      Rails.logger.error "Proof #{proof_type} #{status} failed in #{result[:duration_ms]}ms: #{result[:error]&.message}"
    end
  end

  def self.build_context(result, proof_type, status)
    context = {
      proof_type: proof_type,
      status: status,
      success: result[:success],
      duration_ms: result[:duration_ms],
      environment: Rails.env,
      transaction_id: SecureRandom.uuid
    }
    context[:blob_size_bytes] = result[:blob_size] if result[:success] && result[:blob_size].present?
    if result[:error]
      context[:error_class]    = result[:error].class.name
      context[:error_message]  = result[:error].message
      context[:error_backtrace] = result[:error].backtrace.first(3) if result[:error].backtrace
    end
    context
  end

  def self.record_datadog_metrics(result, _context, proof_type, status)
    return unless defined?(Datadog)

    tags = [
      "proof_type:#{proof_type}",
      "status:#{status}",
      "success:#{result[:success]}",
      "environment:#{Rails.env}"
    ]
    Datadog.increment('proof_attachments.operations', tags: tags)
    Datadog.timing('proof_attachments.duration', result[:duration_ms], tags: tags)
    return unless result[:success] && result[:blob_size].present?

    Datadog.histogram('proof_attachments.size', result[:blob_size],
                      tags: tags)
  end

  # private class methods
  class << self
    private

    def perform_attachment_flow(result, params)
      application = params.fetch(:application)
      proof_type = params.fetch(:proof_type)
      attachment_param = prepare_attachment_param(params.fetch(:blob_or_file), proof_type)
      blob_size = calculate_blob_size(params.fetch(:blob_or_file))
      submission_method = params.fetch(:submission_method)

      # Set paper context for the entire flow if this is a paper submission
      with_paper_context(submission_method, proof_type) do
        attach_and_verify_initial_save(application, proof_type, attachment_param)

        log_attachment_events(application, proof_type, params.fetch(:status), submission_method,
                              params.fetch(:admin), params.fetch(:metadata), params.fetch(:blob_or_file), blob_size,
                              skip_audit_events: params.fetch(:skip_audit_events))

        verify_attachment_persisted_after_update(application, proof_type)

        result[:blob_size] = blob_size
        result[:success] = true
      end
    end

    def attach_and_verify_initial_save(application, proof_type, attachment_param)
      application.send("#{proof_type}_proof").attach(attachment_param)
      application.reload
      raise 'Attachment failed to persist before transaction' unless application.send("#{proof_type}_proof").attached?
    end

    def verify_attachment_persisted_after_update(application, proof_type)
      application.reload
      raise 'Critical error: Attachment disappeared after status update' unless application.send("#{proof_type}_proof").attached?
    end

    def log_error(error)
      Rails.logger.error "Proof attachment error: #{error.message}"
      Rails.logger.error error.backtrace&.join("\n") || 'No backtrace available'
    end

    def log_failure_audit_event(error, context)
      application = context.fetch(:application)
      proof_type = context.fetch(:proof_type)

      # Reuse build_context to generate a consistent error payload
      result_for_context = { success: false, error: error }
      audit_metadata = build_context(result_for_context, proof_type, :attachment_failed)

      # Add submission method, which is not part of the standard metrics context
      safe_submission_method = determine_submission_method(application, context.fetch(:submission_method))
      audit_metadata[:submission_method] = safe_submission_method

      # Merge with original metadata from the call site
      final_metadata = context.fetch(:metadata).merge(audit_metadata)

      AuditEventService.log(
        action: "#{proof_type}_proof_attachment_failed",
        auditable: application,
        actor: context.fetch(:admin) || application.user,
        metadata: final_metadata
      )
    rescue StandardError => e
      # Don't let audit failures affect the main flow
      Rails.logger.error "Failed to record audit for failure: #{e.message}"
    end

    def determine_submission_method(application, submission_method)
      method = application.submission_method.presence || submission_method.presence
      method ? method.to_sym : SubmissionMethodValidator.validate(submission_method)
    end

    def with_service_flow(context)
      start_time = Time.current
      result = { success: false, error: nil, duration_ms: 0 }

      begin
        yield(result)
      rescue StandardError => e
        result[:success] = false
        result[:error] = e
        # The failure context for record_failure is the same as the main context
        record_failure(e, context)
      ensure
        result[:duration_ms] = ((Time.current - start_time) * 1000).round
        record_metrics(result, context.fetch(:proof_type), context.fetch(:status))
      end

      result
    end

    def calculate_blob_size(blob_or_file)
      return blob_or_file.byte_size if blob_or_file.respond_to?(:byte_size)
      return blob_or_file.size if blob_or_file.respond_to?(:size)
      0
    end

    def prepare_attachment_param(blob_or_file, proof_type)
      # ENHANCED LOGGING FOR ATTACHMENT DEBUGGING
      Rails.logger.info "PROOF ATTACHMENT INPUT TYPE: #{blob_or_file.class.name}"

      # Handle ActiveStorage::Blob - return blob directly instead of signed_id
      # This fixes attachment persistence issues in some test environments
      return blob_or_file if blob_or_file.is_a?(ActiveStorage::Blob)

      # Handle signed_id strings
      return blob_or_file if blob_or_file.is_a?(String) && blob_or_file.start_with?('eyJf')

      # Handle uploaded files
      if blob_or_file.respond_to?(:tempfile) || blob_or_file.is_a?(ActionDispatch::Http::UploadedFile)
        begin
          blob = ActiveStorage::Blob.create_and_upload!(
            io: blob_or_file.tempfile,
            filename: blob_or_file.original_filename,
            content_type: blob_or_file.content_type
          )
          Rails.logger.info "Successfully created blob for #{proof_type}_proof: #{blob.id}"
          return blob.signed_id
        rescue StandardError => e
          Rails.logger.error "Failed to create blob from uploaded file: #{e.message}"
          # Continue to default return
        end
      end

      # Default case for all other types and fallback scenarios
      Rails.logger.info "Using raw blob_or_file for #{proof_type}_proof"
      blob_or_file
    end

    def log_attachment_events(application, proof_type, status, submission_method, admin, metadata, blob_or_file,
                              blob_size, skip_audit_events: false)
      # Get the blob ID from the actually attached blob
      attached_blob = application.send("#{proof_type}_proof").blob
      blob_id = attached_blob&.id

      # Create audit and notification record
      event_metadata = metadata.merge(
        proof_type: proof_type,
        submission_method: submission_method,
        status: status,
        has_attachment: true,
        blob_id: blob_id,
        blob_size: blob_size,
        success: true,
        filename: attached_blob&.filename.to_s
      )

      # Only create audit event if not skipped (allows controllers to handle their own audit events)
      unless skip_audit_events
        AuditEventService.log(
          action: "#{proof_type}_proof_attached",
          auditable: application,
          actor: admin || application.user,
          metadata: event_metadata
        )
      end

      ActiveRecord::Base.transaction do
        # Update status
        status_attrs = { "#{proof_type}_proof_status" => status }
        status_attrs[:needs_review_since] = Time.current if status == :not_reviewed

        application.update!(status_attrs)
      end

      NotificationService.create_and_deliver!(
        type: "#{proof_type}_proof_attached",
        recipient: application.user,
        actor: admin || application.user,
        notifiable: application,
        metadata: event_metadata
      )
    end

    def perform_rejection(application:, proof_type:, admin:, submission_method:, rejection_details:)
      reason = rejection_details.fetch(:reason, 'other')
      notes = rejection_details.fetch(:notes, nil)

      with_paper_context(submission_method, proof_type) do
        application.reject_proof_without_attachment!(
          proof_type,
          admin: admin,
          reason: reason,
          notes: notes || 'Rejected during paper application submission'
        )
      end
    end

    def log_rejection_events(application:, proof_type:, admin:, submission_method:, rejection_details:)
      reason = rejection_details.fetch(:reason, 'other')
      metadata = rejection_details.fetch(:metadata, {})
      audit_metadata = metadata.merge(
        proof_type: proof_type,
        submission_method: submission_method,
        status: :rejected,
        has_attachment: false,
        rejection_reason: reason
      )

      AuditEventService.log(
        action: "#{proof_type}_proof_rejected",
        auditable: application,
        actor: admin,
        metadata: audit_metadata
      )
      NotificationService.create_and_deliver!(
        type: "#{proof_type}_proof_rejected",
        recipient: application.user,
        actor: admin,
        notifiable: application,
        metadata: audit_metadata
      )
    end

    def with_paper_context(submission_method, proof_type)
      original_context = Current.paper_context
      original_service_context = Current.proof_attachment_service_context
      begin
        if submission_method.to_sym == :paper
          Current.paper_context = true
          Rails.logger.debug { "ProofAttachmentService: Setting paper_application_context=true for #{proof_type} rejection" }
        end
        # Always set service context to prevent duplicate events from ProofManageable
        Current.proof_attachment_service_context = true
        yield
      ensure
        Current.paper_context = original_context
        Current.proof_attachment_service_context = original_service_context
        Rails.logger.debug { "ProofAttachmentService: Restored paper_application_context=#{original_context.inspect}" }
      end
    end
  end
end
