# frozen_string_literal: true

module Applications
  # Service for reviewing and managing medical certification documents
  # Handles rejection workflow including notifications to provider and application status updates
  class MedicalCertificationReviewer < BaseService
    attr_reader :application, :admin

    def initialize(application, admin)
      super() # Initialize BaseService
      @application = application
      @admin = admin
    end

    # Reject a medical certification with a specific reason
    # Updates application status and notifies provider
    # @param rejection_reason [String] The reason for rejection
    # @param notes [String, nil] Optional additional notes for internal use
    # @return [BaseService::Result] Result object with success status and any error messages
    def reject(rejection_reason:, notes: nil)
      Rails.logger.info "Rejecting medical certification for Application ##{application.id}"

      # Validate inputs
      return failure('Rejection reason is required') if rejection_reason.blank?
      return failure('Admin user is required') if admin.blank?

      # Check if application has a medical provider with contact info
      return failure('Application does not have medical provider information') if application.medical_provider_name.blank?

      # Make sure there's at least one way to contact the provider
      if application.medical_provider_email.blank? && application.medical_provider_fax.blank?
        return failure('No contact method available for medical provider')
      end

      # Call the dedicated service to handle rejection logic (updates status, creates events/notifications)
      service_result = MedicalCertificationAttachmentService.reject_certification(
        application: application,
        admin: admin,
        reason: rejection_reason,
        notes: notes # Pass notes to the service, it includes them in notification/status change metadata
      )

      # Convert hash result to BaseService::Result
      return failure(service_result[:error]&.message || 'Medical certification service failed') unless service_result[:success]

      # If the service call succeeded and notes were provided, create the specific ApplicationNote
      if notes.present?
        begin
          application.application_notes.create!(
            admin: admin, # Correct association name
            content: "Medical certification rejected: #{notes}"
            # Removed non-existent note_type attribute
          )
        rescue StandardError => e
          Rails.logger.error("Failed to create application note: #{e.message}")
          return failure("Medical certification rejected successfully, but note creation failed: #{e.message}")
        end
      end

      success('Medical certification rejected successfully')
    end
  end
end
