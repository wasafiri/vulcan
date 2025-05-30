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
  # @param application [Application] The application to attach the proof to
  # @param proof_type [Symbol] The type of proof (:income or :residency)
  # @param blob_or_file [ActiveStorage::Blob, String, ActionDispatch::Http::UploadedFile]
  #        The file to attach - can be a direct blob, a signed_id string, or an uploaded file
  # @param status [Symbol] The status to set for the proof (:not_reviewed, :approved, :rejected)
  # @param admin [User] The admin user if this is an admin action (nil for constituent actions)
  # @param submission_method [Symbol] The method of submission (:paper, :web, :email, etc.)
  # @param metadata [Hash] Additional metadata to store with the attachment audit
  #
  # @return [Hash] Result hash with :success, :error, and :duration_ms keys
  def self.attach_proof(application:, proof_type:, blob_or_file:, submission_method:, status: :not_reviewed,
                        admin: nil, metadata: {})
    start_time = Time.current
    result = { success: false, error: nil, duration_ms: 0 }

    # Calculate blob size for metrics if available
    blob_size = blob_or_file.byte_size if blob_or_file.respond_to?(:byte_size)

    begin
      # Step 1: Process blob_or_file to ensure it's in the right format for attachment
      # ActiveStorage attach requires a signed_id, IO object, Hash with keys, or ActionDispatch::Http::UploadedFile
      attachment_param = blob_or_file

      # ENHANCED LOGGING FOR ATTACHMENT DEBUGGING
      Rails.logger.info "PROOF ATTACHMENT INPUT TYPE: #{blob_or_file.class.name}"
      Rails.logger.info "PROOF ATTACHMENT ENVIRONMENT: #{Rails.env}"
      Rails.logger.info "PROOF ATTACHMENT STORAGE SERVICE: #{ActiveStorage::Blob.service.class.name}"

      # Proper handling of different input types
      if blob_or_file.is_a?(ActiveStorage::Blob)
        # Direct blob object - convert to signed_id
        Rails.logger.info "Converting blob to signed_id for #{proof_type} proof attachment"
        Rails.logger.info "BLOB INFO: ID=#{blob_or_file.id}, Key=#{blob_or_file.key}, Content-Type=#{blob_or_file.content_type}, Size=#{blob_or_file.byte_size}"
        attachment_param = blob_or_file.signed_id
        Rails.logger.info "Using signed_id: #{attachment_param || '[nil]'}"
      elsif blob_or_file.is_a?(String) && blob_or_file.start_with?('eyJf')
        # Already a signed_id string - use as is
        Rails.logger.info "Input is already a signed_id, using directly: #{blob_or_file[0..20]}..."
        attachment_param = blob_or_file
      elsif blob_or_file.respond_to?(:tempfile) || blob_or_file.is_a?(ActionDispatch::Http::UploadedFile)
        # ActionDispatch::Http::UploadedFile or similar - use as is
        if blob_or_file.respond_to?(:original_filename)
          Rails.logger.info "UPLOAD INFO: Filename=#{blob_or_file.original_filename}, Content-Type=#{blob_or_file.content_type}, Size=#{blob_or_file.size}"
        end
        Rails.logger.info "Using direct file upload attachment: #{blob_or_file.class.name}"
        attachment_param = blob_or_file

        # Create ActiveStorage blob directly for more reliable attachment
        Rails.logger.info 'Creating blob from uploaded file'
        begin
          blob = ActiveStorage::Blob.create_and_upload!(
            io: blob_or_file.tempfile,
            filename: blob_or_file.original_filename,
            content_type: blob_or_file.content_type
          )
          Rails.logger.info "Successfully created blob for #{proof_type}_proof: #{blob.id}"
          attachment_param = blob.signed_id
        rescue StandardError => e
          Rails.logger.error "Failed to create blob from uploaded file: #{e.message}"
          # Continue with original param as fallback
        end
      else
        # Other types (IO, Hash, etc) - use as is
        Rails.logger.info "ATTACHMENT PARAM TYPE: #{blob_or_file.class.name}"
        begin
          Rails.logger.info "ATTACHMENT PARAM DETAILS: #{blob_or_file.inspect[0..100]}"
        rescue StandardError
          'Could not inspect blob_or_file'
        end
        attachment_param = blob_or_file
      end

      # Log pre-attachment info
      Rails.logger.info "PRE-ATTACHMENT CHECK: Application #{application.id}, #{proof_type}_proof attached? #{application.send("#{proof_type}_proof").attached?}"

      # Step 2: Attach directly to the application instance
      Rails.logger.info "EXECUTING ATTACHMENT: #{proof_type}_proof to application #{application.id}"
      application.send("#{proof_type}_proof").attach(attachment_param)

      # Force a reload of the application *before* the transaction to ensure attachment is recognized
      application.reload

      # Log details to help debug attachments
      Rails.logger.debug do
        "Attachment check - application_id: #{application.id}, #{proof_type}_proof attached? #{application.send("#{proof_type}_proof").attached?}"
      end
      if application.send("#{proof_type}_proof").attached?
        attachment = application.send("#{proof_type}_proof").attachment
        Rails.logger.info "Attachment confirmed - ID: #{attachment.id}, Blob ID: #{attachment.blob_id}"
      end

      # Verify attachment succeeded before proceeding within the transaction
      Rails.logger.info "Successfully attached #{proof_type} proof for application #{application.id}, proceeding to update status."

      # Step 3: Update status and create audit record in a single transaction
      ActiveRecord::Base.transaction do
        # Update status
        status_attrs = { "#{proof_type}_proof_status" => status }
        status_attrs[:needs_review_since] = Time.current if status == :not_reviewed

        # Preserve the paper_application_context flag during update
        # This ensures validations that check this flag work correctly
        original_context = Thread.current[:paper_application_context]
        begin
          # If this is a paper application submission, ensure the flag is set
          if submission_method.to_sym == :paper
            Thread.current[:paper_application_context] = true
            Rails.logger.debug { "ProofAttachmentService: Setting paper_application_context=true for #{proof_type} update" }
          end

          application.update!(status_attrs)
        ensure
          # Restore the original context value
          Thread.current[:paper_application_context] = original_context
          Rails.logger.debug { "ProofAttachmentService: Restored paper_application_context=#{original_context.inspect}" }
        end

        Rails.logger.info "Updated #{proof_type} proof status to #{status} for application #{application.id}"

        # Create audit record
        ProofSubmissionAudit.create!(
          application: application,
          user: admin || application.user,
          proof_type: proof_type,
          submission_method: submission_method,
          ip_address: metadata[:ip_address] || '0.0.0.0',
          metadata: metadata.merge(
            success: true,
            status: status,
            has_attachment: true,
            blob_id: blob_or_file.respond_to?(:id) ? blob_or_file.id : nil,
            blob_size: blob_size
          )
        )
      end

      # Final verification after status update
      application.reload
      raise 'Critical error: Attachment disappeared after status update' unless application.send("#{proof_type}_proof").attached?

      # Set blob size for metrics
      result[:blob_size] = blob_size
      result[:success] = true
    rescue StandardError => e
      # Explicitly set success to false on error
      result[:success] = false
      # Track failure with detailed information
      record_failure(application, proof_type, e, admin, submission_method, metadata)
      result[:error] = e
    ensure
      result[:duration_ms] = ((Time.current - start_time) * 1000).round
      record_metrics(result, proof_type, status)
    end

    result
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
  # @param reason [String] The reason for rejection (e.g., 'unclear', 'incomplete', 'other')
  # @param notes [String, nil] Optional notes explaining the rejection
  # @param submission_method [Symbol] The method of submission (:paper, :web, :email, etc.)
  # @param metadata [Hash] Additional metadata to store with the rejection audit
  #
  # @return [Hash] Result hash with :success, :error, and :duration_ms keys
  def self.reject_proof_without_attachment(application:, proof_type:, admin:, submission_method:, reason: 'other',
                                           notes: nil, metadata: {})
    start_time = Time.current
    result = { success: false, error: nil, duration_ms: 0 }

    begin
      # Preserve the paper_application_context flag during rejection
      # This ensures validations that check this flag work correctly
      original_context = Thread.current[:paper_application_context]
      begin
        # If this is a paper application submission, ensure the flag is set
        if submission_method.to_sym == :paper
          Thread.current[:paper_application_context] = true
          Rails.logger.debug { "ProofAttachmentService: Setting paper_application_context=true for #{proof_type} rejection" }
        end

        # Use the existing method that's been verified to work
        success = application.reject_proof_without_attachment!(
          proof_type,
          admin: admin,
          reason: reason,
          notes: notes || 'Rejected during paper application submission'
        )
      ensure
        # Restore the original context value
        Thread.current[:paper_application_context] = original_context
        Rails.logger.debug { "ProofAttachmentService: Restored paper_application_context=#{original_context.inspect}" }
      end

      if success
        # Create audit record for tracking and metrics
        ProofSubmissionAudit.create!(
          application: application,
          user: admin,
          proof_type: proof_type,
          submission_method: submission_method,
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
    rescue StandardError => e
      record_failure(application, proof_type, e, admin, submission_method, metadata)
      result[:error] = e
    ensure
      result[:duration_ms] = ((Time.current - start_time) * 1000).round
      record_metrics(result, proof_type, :rejected)
    end

    result
  end

  def self.record_failure(application, proof_type, error, admin, submission_method, metadata)
    Rails.logger.error "Proof attachment error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")

    begin
      # Get the application's submission method if available, otherwise use the parameter
      app_submission_method = application.submission_method.to_sym if application.submission_method.present?

      # Use application's submission method first, then fall back to parameter, then to validator
      safe_submission_method = app_submission_method ||
                               (submission_method.present? ? submission_method.to_sym : nil) ||
                               SubmissionMethodValidator.validate(submission_method)

      # Record the failure for metrics and monitoring
      ProofSubmissionAudit.create!(
        application: application,
        user: admin || application.user,
        proof_type: proof_type,
        submission_method: safe_submission_method,
        ip_address: metadata[:ip_address] || '0.0.0.0',
        metadata: metadata.merge(
          success: false,
          error_class: error.class.name,
          error_message: error.message,
          error_backtrace: error.backtrace.first(5)
        )
      )
    rescue StandardError => e
      # Don't let audit failures affect the main flow
      Rails.logger.error "Failed to record audit for failure: #{e.message}"
    end

    # Report to error tracking service if available
    if defined?(Honeybadger)
      Honeybadger.notify(error,
                         context: {
                           application_id: application.id,
                           proof_type: proof_type,
                           admin_id: admin&.id,
                           metadata: metadata
                         })
    end
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
end
