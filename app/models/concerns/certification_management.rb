# frozen_string_literal: true

# Handles all operations related to medical certification management
# This includes requesting, receiving, and verifying medical certifications
module CertificationManagement
  extend ActiveSupport::Concern

  # Determines if medical certification has been requested
  def medical_certification_requested?
    medical_certification_requested_at.present? ||
      medical_certification_status.in?(%w[requested received approved rejected])
  end

  # Determines if medical certification has been approved
  def medical_certification_status_approved?
    medical_certification_status == "approved"
  end

  # Updates the certification with the given status and reviewer
  # @param certification [ActionDispatch::Http::UploadedFile] The uploaded certification file
  # @param status [String] The new status ('approved', 'rejected', 'received')
  # @param verified_by [User] The admin who verified the certification
  # @param rejection_reason [String, nil] Reason for rejection if status is 'rejected'
  # @return [Boolean] True if the certification was updated successfully
  def update_certification!(certification:, status:, verified_by:, rejection_reason: nil)
    Rails.logger.info 'Using MedicalCertificationAttachmentService for certification update'

    if status == 'rejected' && rejection_reason.present?
      # Use the reject_certification method for rejections
      result = MedicalCertificationAttachmentService.reject_certification(
        application: self,
        admin: verified_by,
        reason: rejection_reason,
        submission_method: 'api',
        metadata: {
          api_call: true
        }
      )
    elsif medical_certification.attached? && certification.blank?
      # Status-only update for existing certification (no new file)
      result = MedicalCertificationAttachmentService.update_certification_status(
        application: self,
        status: status.to_sym,
        admin: verified_by,
        submission_method: 'api',
        metadata: {
          api_call: true,
          rejection_reason: rejection_reason
        }
      )
    else
      # Use the attach_certification method for uploads
      result = MedicalCertificationAttachmentService.attach_certification(
        application: self,
        blob_or_file: certification,
        status: status.to_sym,
        admin: verified_by,
        submission_method: 'api',
        metadata: {
          api_call: true,
          rejection_reason: rejection_reason
        }
      )
    end

    result[:success]
  rescue StandardError => e
    Rails.logger.error "Failed to update certification: #{e.message}"
    false
  end
end
