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
      return failure_result('Admin user is required') unless admin.present?
      
      # Check if application has a medical provider with contact info
      unless application.medical_provider_name.present?
        return failure_result('Application does not have medical provider information')
      end
      
      # Make sure there's at least one way to contact the provider
      unless application.medical_provider_email.present? || application.medical_provider_fax.present?
        return failure_result('No contact method available for medical provider')
      end
      
      # Attempt to update application status to rejected
      application.transaction do
        # Update medical certification status
        begin
          # Pass nil for certification when rejecting - we don't need to attach anything
          application.update_certification!(
            certification: nil,
            status: :rejected,
            verified_by: admin,
            rejection_reason: rejection_reason
          )
        rescue StandardError => e
          return failure_result("Failed to update application: #{e.message}")
        end
        
        # Add notes if provided
        if notes.present?
          application.application_notes.create!(
            author: admin,
            content: "Medical certification rejected: #{notes}",
            note_type: 'medical_certification'
          )
        end
        
        # Record the status change in audit log
        ApplicationStatusChange.create!(
          application: application,
          user: admin,
          from_status: 'pending',
          to_status: 'rejected',
          change_type: 'medical_certification',
          metadata: {
            rejection_reason: rejection_reason,
            provider_name: application.medical_provider_name,
            timestamp: Time.current.iso8601
          }
        )
        
        # Notify the medical provider
        notifier = MedicalProviderNotifier.new(application)
        notification_sent = notifier.notify_certification_rejection(
          rejection_reason: rejection_reason,
          admin: admin
        )
        
        unless notification_sent
          Rails.logger.warn "Certification rejected but failed to notify provider for Application ##{application.id}"
        end
      end
      
      success_result
    rescue StandardError => e
      failure_result("Unexpected error: #{e.message}")
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
