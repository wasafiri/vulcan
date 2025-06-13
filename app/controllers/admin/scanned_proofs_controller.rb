# frozen_string_literal: true

module Admin
  class ScannedProofsController < Admin::BaseController
    before_action :set_application
    before_action :validate_proof_type, only: %i[new create]
    before_action :validate_file, only: [:create]

    ALLOWED_CONTENT_TYPES = [
      'application/pdf',
      'image/jpeg',
      'image/png',
      'image/tiff'
    ].freeze

    MAX_FILE_SIZE = 10.megabytes

    def new
      @proof_type = params[:proof_type]
    end

    def create
      begin
        # Use ApplicationRecord.transaction for consistency with Rails 7+ and to keep
        # domain logic near your ApplicationRecord base class if needed.
        ApplicationRecord.transaction do
          attach_proof
          # Note: audit trail is handled by ProofAttachmentService.attach_proof
        end

        success = true
      rescue ActiveRecord::RecordInvalid, ActiveStorage::IntegrityError => e
        # For record or integrity errors, let the user retry on the form page.
        redirect_to new_admin_application_scanned_proof_path(@application),
                    alert: e.message
        return
      rescue StandardError => e
        # Log any unexpected error and let the user know to try again.
        Rails.logger.error("Proof upload failed: #{e.message}")
        redirect_to admin_application_path(@application),
                    alert: 'Error uploading proof. Please try again.'
        return
      end

      # Only proceed with notification if the upload was successful
      return unless success

      begin
        # Best practice: run notifications outside the transaction so a rollback
        # doesn't prevent them. Consider using a background job if it's a heavier process.
        notify_constituent
      rescue StandardError => e
        Rails.logger.error("Failed to send notification: #{e.message}")
        # Don't fail the upload if just the notification fails
      end

      redirect_to admin_application_path(@application),
                  notice: 'Proof successfully uploaded and attached'
    end

    private

    def set_application
      @application = Application.find(params[:application_id])
    rescue ActiveRecord::RecordNotFound
      redirect_to admin_applications_path, alert: 'Application not found'
    end

    def validate_proof_type
      return if %w[income residency].include?(params[:proof_type])

      redirect_to admin_application_path(@application),
                  alert: 'Invalid proof type'
    end

    def validate_file
      return redirect_to(new_admin_application_scanned_proof_path(@application),
                         alert: 'Please select a file to upload') if params[:file].blank?

      return redirect_to(new_admin_application_scanned_proof_path(@application),
                         alert: 'File type not allowed') unless valid_file_type?

      return if valid_file_size?

      redirect_to(new_admin_application_scanned_proof_path(@application),
                  alert: "File size must be under #{MAX_FILE_SIZE / 1.megabyte}MB")
    end

    def valid_file_type?
      ALLOWED_CONTENT_TYPES.include?(params[:file].content_type)
    end

    def valid_file_size?
      params[:file].size <= MAX_FILE_SIZE
    end

    def attach_proof
      result = ProofAttachmentService.attach_proof({
        application: @application,
        proof_type: params[:proof_type].to_sym,
        blob_or_file: params[:file],
        status: :approved,
        admin: current_user,
        submission_method: :paper,
        skip_audit_events: true, # Admin controller handles its own audit events
        metadata: {
          scanned_by: current_user.id,
          scan_location: params[:scan_location] || 'central_office'
        }
      })
      raise "Failed to attach proof: #{result[:error]&.message}" unless result[:success]
      
      # Create tracking event for audit trail (similar to constituent portal)
      track_submission
    end

    def track_submission
      # Get the blob ID from the actually attached blob for consistency with ProofAttachmentService
      attached_blob = @application.send("#{params[:proof_type]}_proof").blob
      
      # Create Event for application audit log (matches constituent portal pattern)
      AuditEventService.log(
        action: 'proof_submitted',
        actor: current_user,
        auditable: @application,
        metadata: {
          proof_type: params[:proof_type],
          submission_method: 'paper',
          success: true,
          blob_id: attached_blob&.id,
          filename: params[:file].original_filename
        }
      )
    end

    def create_audit_trail
      # Store additional file info in the metadata column
      metadata = {
        user_agent: request.user_agent,
        filename: params[:file].original_filename,
        file_size: params[:file].size,
        content_type: params[:file].content_type
      }

      AuditEventService.log(
        action: "#{params[:proof_type]}_proof_attached",
        auditable: @application,
        actor: current_user,
        metadata: metadata
      )
    end

    def notify_constituent
      ApplicationNotificationsMailer.proof_received(
        @application,
        params[:proof_type]
      ).deliver_later
    rescue StandardError => e
      Rails.logger.error("Failed to queue notification: #{e.message}")
      # Continue without failing the upload
    end
  end
end
