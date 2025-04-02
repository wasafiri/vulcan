# frozen_string_literal: true

# Service to handle medical certification attachments with consistent transaction handling
#
# This service follows the same pattern as ProofAttachmentService but is specifically
# tailored for handling medical certification attachments, ensuring reliable uploads
# and consistent status tracking.
#
# Key responsibilities:
# 1. Handle blob/file conversion for different input types
# 2. Provide a unified interface for attaching medical certifications
# 3. Maintain audit records for all attachment operations
# 4. Provide consistent error handling and logging
class MedicalCertificationAttachmentService
  # Attaches a medical certification document to an application
  #
  # @param application [Application] The application to attach the certification to
  # @param blob_or_file [ActiveStorage::Blob, String, ActionDispatch::Http::UploadedFile]
  #        The file to attach - can be a direct blob, a signed_id string, or an uploaded file
  # @param status [Symbol] The status to set (:accepted, :rejected, :received)
  # @param admin [User] The admin user performing this action
  # @param submission_method [Symbol] The method of submission (:fax, :email, :portal, etc.)
  # @param metadata [Hash] Additional metadata to store with the operation
  #
  # @return [Hash] Result hash with :success, :error, and :duration_ms keys
  def self.attach_certification(application:, blob_or_file:, status: :accepted, 
                                admin: nil, submission_method: :admin_upload, metadata: {})
    start_time = Time.current
    result = { success: false, error: nil, duration_ms: 0 }

    # Calculate blob size for metrics if available
    blob_size = blob_or_file.byte_size if blob_or_file.respond_to?(:byte_size)

    begin
      # Step 1: Process blob_or_file to ensure it's in the right format for attachment
      Rails.logger.info "MEDICAL CERTIFICATION ATTACHMENT INPUT TYPE: #{blob_or_file.class.name}"
      Rails.logger.info "MEDICAL CERTIFICATION ENVIRONMENT: #{Rails.env}"
      Rails.logger.info "MEDICAL CERTIFICATION STORAGE SERVICE: #{ActiveStorage::Blob.service.class.name}"

      attachment_param = process_attachment_param(blob_or_file)
      
      # Step 2: Direct attachment first, outside any transaction
      Rails.logger.info "EXECUTING ATTACHMENT: medical_certification to application #{application.id}"

      # Create a fresh attachment: attach directly to a record obtained from a fresh query
      fresh_application = Application.unscoped.find(application.id)
      fresh_application.medical_certification.attach(attachment_param)

      # Force a reload of the application to ensure we see latest changes
      application = Application.unscoped.find(application.id)

      # Verify attachment succeeded before proceeding
      unless verify_attachment(application)
        raise "Failed to verify attachment: medical_certification not attached after direct attachment"
      end

      Rails.logger.info "Successfully verified medical certification attachment for application #{application.id}"

      # Step 3: Update status and create audit record in a single transaction
      update_certification_status(application, status, admin, submission_method, metadata)

      # Final verification after status update
      application.reload
      unless application.medical_certification.attached?
        raise 'Critical error: Attachment disappeared after status update'
      end

      # Set blob size for metrics
      result[:blob_size] = blob_size
      result[:success] = true
    rescue StandardError => e
      # Track failure with detailed information
      record_failure(application, e, admin, submission_method, metadata)
      result[:error] = e
    ensure
      result[:duration_ms] = ((Time.current - start_time) * 1000).round
      record_metrics(result, status)
    end

    result
  end

  # Reject a medical certification without requiring a file attachment
  def self.reject_certification(application:, admin:, reason:, notes: nil, 
                               submission_method: :admin_review, metadata: {})
    start_time = Time.current
    result = { success: false, error: nil, duration_ms: 0 }

    begin
      ActiveRecord::Base.transaction do
        # Update certification status
        application.update!(
          medical_certification_status: 'rejected',
          medical_certification_verified_at: Time.current,
          medical_certification_verified_by_id: admin.id,
          medical_certification_rejection_reason: reason
        )

        # Create ApplicationStatusChange record
        ApplicationStatusChange.create!(
          application: application,
          user: admin,
          from_status: application.medical_certification_status_was || 'requested',
          to_status: 'rejected',
          metadata: {
            change_type: 'medical_certification',
            submission_method: submission_method,
            verified_at: Time.current.iso8601,
            verified_by_id: admin.id,
            rejection_reason: reason,
            notes: notes
          },
          notes: notes
        )

        # Create event for audit trail
        Event.create!(
          user: admin,
          action: 'medical_certification_status_changed',
          metadata: {
            application_id: application.id,
            old_status: application.medical_certification_status_was || 'requested',
            new_status: 'rejected',
            timestamp: Time.current.iso8601,
            change_type: 'medical_certification',
            reason: reason
          }
        )

        # Create notification
        Notification.create!(
          recipient: application.user,
          actor: admin,
          action: 'medical_certification_rejected',
          notifiable: application,
          metadata: {
            'reason' => reason,
            'notes' => notes
          }
        )
      end

      result[:success] = true
    rescue StandardError => e
      record_failure(application, e, admin, submission_method, metadata)
      result[:error] = e
    ensure
      result[:duration_ms] = ((Time.current - start_time) * 1000).round
      record_metrics(result, :rejected)
    end

    result
  end

  private

  def self.process_attachment_param(blob_or_file)
    attachment_param = blob_or_file
    
    if blob_or_file.is_a?(ActiveStorage::Blob)
      # Direct blob object - convert to signed_id
      Rails.logger.info "Converting blob to signed_id for medical certification attachment"
      Rails.logger.info "BLOB INFO: ID=#{blob_or_file.id}, Key=#{blob_or_file.key}, Content-Type=#{blob_or_file.content_type}, Size=#{blob_or_file.byte_size}"
      attachment_param = blob_or_file.signed_id
      Rails.logger.info "Using signed_id: #{attachment_param || '[nil]'}"
    elsif blob_or_file.is_a?(String) && blob_or_file.start_with?('eyJf')
      # Already a signed_id string - use as is
      Rails.logger.info "Input is already a signed_id, using directly: #{blob_or_file[0..20]}..."
      attachment_param = blob_or_file
    elsif blob_or_file.respond_to?(:tempfile) || blob_or_file.is_a?(ActionDispatch::Http::UploadedFile)
      # ActionDispatch::Http::UploadedFile or similar - create a blob
      if blob_or_file.respond_to?(:original_filename)
        Rails.logger.info "UPLOAD INFO: Filename=#{blob_or_file.original_filename}, Content-Type=#{blob_or_file.content_type}, Size=#{blob_or_file.size}"
      end
      
      # Create ActiveStorage blob directly for more reliable attachment
      Rails.logger.info 'Creating blob from uploaded file'
      begin
        blob = ActiveStorage::Blob.create_and_upload!(
          io: blob_or_file.tempfile,
          filename: blob_or_file.original_filename,
          content_type: blob_or_file.content_type
        )
        Rails.logger.info "Successfully created blob for medical_certification: #{blob.id}"
        attachment_param = blob.signed_id
      rescue StandardError => e
        Rails.logger.error "Failed to create blob from uploaded file: #{e.message}"
        # Continue with original param as fallback
      end
    end
    
    attachment_param
  end

  def self.verify_attachment(application)
    # Check if the attachment is present
    if application.medical_certification.attached?
      attachment = application.medical_certification.attachment
      Rails.logger.info "Attachment confirmed - ID: #{attachment.id}, Blob ID: #{attachment.blob_id}"
      return true
    end
    
    # Try one last manual DB query to check if attachment exists
    attachment_exists = ActiveStorage::Attachment.where(
      record_type: 'Application',
      record_id: application.id,
      name: "medical_certification"
    ).exists?
    
    unless attachment_exists
      return false
    end
    
    Rails.logger.warn 'Attachment exists in DB but not detected in model - forcing reset'
    application.medical_certification.reset
    true
  end

  def self.update_certification_status(application, status, admin, submission_method, metadata)
    ActiveRecord::Base.transaction do
      # Update certification status
      application.update!(
        medical_certification_status: status.to_s,
        medical_certification_verified_at: Time.current,
        medical_certification_verified_by_id: admin&.id
      )
      
      Rails.logger.info "Updated medical certification status to #{status} for application #{application.id}"
      
      # Create ApplicationStatusChange record
      ApplicationStatusChange.create!(
        application: application,
        user: admin,
        from_status: application.medical_certification_status_was || 'requested',
        to_status: status.to_s,
        metadata: {
          change_type: 'medical_certification',
          submission_method: submission_method.to_s,
          verified_at: Time.current.iso8601,
          verified_by_id: admin&.id
        }
      )
      
      # Create event for audit trail
      Event.create!(
        user: admin,
        action: 'medical_certification_status_changed',
        metadata: {
          application_id: application.id,
          old_status: application.medical_certification_status_was || 'requested',
          new_status: status.to_s,
          timestamp: Time.current.iso8601,
          change_type: 'medical_certification'
        }
      )
      
      # Create notification if needed
      action_mapping = {
        accepted: 'medical_certification_approved',
        rejected: 'medical_certification_rejected',
        received: 'medical_certification_received'
      }
      
      if action = action_mapping[status.to_sym]
        Notification.create!(
          recipient: application.user,
          actor: admin,
          action: action,
          notifiable: application,
          metadata: metadata
        )
      end
    end
  end

  def self.record_failure(application, error, admin, submission_method, metadata)
    Rails.logger.error "Medical certification attachment error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    begin
      # Create an event to track the error
      Event.create!(
        user: admin,
        action: 'medical_certification_attachment_failed',
        metadata: {
          application_id: application.id,
          error_class: error.class.name,
          error_message: error.message,
          submission_method: submission_method.to_s,
          timestamp: Time.current.iso8601
        }
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
                           admin_id: admin&.id,
                           metadata: metadata
                         })
    end
  rescue StandardError => e
    # Last resort logging if even the failure tracking fails
    Rails.logger.error "Failed to record medical certification failure: #{e.message}"
  end

  def self.record_metrics(result, status)
    # Basic logging
    if result[:success]
      Rails.logger.info "Medical certification #{status} completed in #{result[:duration_ms]}ms"
    else
      Rails.logger.error "Medical certification #{status} failed in #{result[:duration_ms]}ms: #{result[:error]&.message}"
    end
    
    # Build context for metrics
    context = {
      status: status,
      success: result[:success],
      duration_ms: result[:duration_ms],
      environment: Rails.env,
      transaction_id: SecureRandom.uuid
    }
    
    if result[:error]
      context[:error_class] = result[:error].class.name
      context[:error_message] = result[:error].message
      context[:error_backtrace] = result[:error].backtrace.first(3) if result[:error].backtrace
    end
    
    Rails.logger.info("METRICS: medical_certification #{context.to_json}")
  rescue StandardError => e
    Rails.logger.error "Failed to record medical certification metrics: #{e.message}"
  end
end
