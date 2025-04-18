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
          create_audit_trail
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
      if success
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
      case params[:proof_type]
      when 'income'
        @application.income_proof.attach(params[:file])
        proof_type = :income_proof_status
      when 'residency'
        @application.residency_proof.attach(params[:file])
        proof_type = :residency_proof_status
      else
        raise ArgumentError, 'Invalid proof type'
      end

      @application.update!(
        proof_type => :not_reviewed,
        needs_review_since: Time.current,
        last_proof_submitted_at: Time.current
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
      
      ProofSubmissionAudit.create!(
        application: @application,
        user: current_user,
        proof_type: params[:proof_type],
        submission_method: :paper, # Use the correct enum value from ProofSubmissionAudit model
        ip_address: request.remote_ip,
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
