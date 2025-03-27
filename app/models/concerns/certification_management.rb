# frozen_string_literal: true

# Handles all operations related to medical certification management
# This includes requesting, receiving, and verifying medical certifications
module CertificationManagement
  extend ActiveSupport::Concern

  # Determines if medical certification has been requested
  def medical_certification_requested?
    medical_certification_requested_at.present? ||
      medical_certification_status.in?(%w[requested received accepted rejected])
  end

  # Updates the certification with the given status and reviewer
  # @param certification [ActionDispatch::Http::UploadedFile] The uploaded certification file
  # @param status [String] The new status ('accepted', 'rejected', 'received')
  # @param verified_by [User] The admin who verified the certification
  # @param rejection_reason [String, nil] Reason for rejection if status is 'rejected'
  # @return [Boolean] True if the certification was updated successfully
  def update_certification!(certification:, status:, verified_by:, rejection_reason: nil)
    with_lock do
      attach_certification_if_needed(certification)
      update_certification_attributes(status, verified_by, rejection_reason)
      create_certification_notification(status, verified_by, rejection_reason)
    end
    true
  rescue ::ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to update certification: #{e.message}"
    false
  end

  private

  def attach_certification_if_needed(certification)
    medical_certification.attach(certification) if certification.present?
  end

  def update_certification_attributes(status, verified_by, rejection_reason)
    attrs = {
      medical_certification_status: status,
      medical_certification_verified_at: Time.current,
      medical_certification_verified_by: verified_by
    }
    attrs[:medical_certification_rejection_reason] = rejection_reason if status == 'rejected'
    update!(attrs)
  end

  def create_certification_notification(status, verified_by, rejection_reason)
    action_mapping = {
      'accepted' => 'medical_certification_approved',
      'rejected' => 'medical_certification_rejected',
      'received' => 'medical_certification_received'
    }
    action = action_mapping[status]
    if action
      metadata = {}
      metadata['reason'] = rejection_reason if rejection_reason.present?
      Notification.create!(
        recipient: user,
        actor: verified_by,
        action: action,
        notifiable: self,
        metadata: metadata
      )
    end
  end
end
