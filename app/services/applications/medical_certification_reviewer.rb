# frozen_string_literal: true

module Applications
  # Service for reviewing and managing medical certification documents
  # Handles rejection workflow including notifications to provider and application status updates
  class MedicalCertificationReviewer
    attr_reader :application, :admin, :errors

    def initialize(application, admin)
      @application = application
      @admin = admin
      @errors = []
    end

    # Reject a medical certification with a specific reason
    # Updates application status and notifies provider
    # @param rejection_reason [String] The reason for rejection
    # @param notes [String, nil] Optional additional notes for internal use
    # @return [Hash] Result hash with success status and any error messages
    def reject(rejection_reason:, notes: nil)
      Rails.logger.info "Rejecting medical certification for Application ##{application.id}"

      # Validate inputs
      return failure_result('Rejection reason is required') if rejection_reason.blank?
      return failure_result('Admin user is required') if admin.blank?

      # Check if application has a medical provider with contact info
      return failure_result('Application does not have medical provider information') if application.medical_provider_name.blank?

      # Make sure there's at least one way to contact the provider
      unless application.medical_provider_email.present? || application.medical_provider_fax.present?
        return failure_result('No contact method available for medical provider')
      end

      # Call the dedicated service to handle rejection logic (updates status, creates events/notifications)
      result = MedicalCertificationAttachmentService.reject_certification(
        application: application,
        admin: admin,
        reason: rejection_reason,
        notes: notes # Pass notes to the service, it includes them in notification/status change metadata
      )

      # If the service call succeeded and notes were provided, create the specific ApplicationNote
      if result[:success] && notes.present?
        # Removed begin/rescue to let potential errors propagate
        application.application_notes.create!(
          admin: admin, # Correct association name
          content: "Medical certification rejected: #{notes}"
          # Removed non-existent note_type attribute
        )
      end

      # Return the result hash from the service call
      result
      # No need for a broad rescue here, the service handles its errors and returns a result hash
    end

    private

    def success_result
      { success: true }
    end

    def failure_result(error_message)
      @errors << error_message
      Rails.logger.error "Medical certification rejection failed: #{error_message} for Application ##{application.id}"
      { success: false, error: error_message }
    end
  end
end
