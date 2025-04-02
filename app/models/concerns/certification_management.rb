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
    return unless certification.present? && !certification.is_a?(Symbol)
    
    Rails.logger.info "MEDICAL CERTIFICATION ATTACHMENT: Input type is #{certification.class.name}"
    
    # Process the attachment parameter based on its type - similar to ProofAttachmentService
    attachment_param = certification
    
    if certification.is_a?(ActiveStorage::Blob)
      # Direct blob object - convert to signed_id
      Rails.logger.info "Converting blob to signed_id for medical certification"
      attachment_param = certification.signed_id
    elsif certification.is_a?(String) && certification.start_with?('eyJf')
      # Already a signed_id string - use as is
      Rails.logger.info "Input is already a signed_id, using directly"
      attachment_param = certification
    elsif certification.respond_to?(:tempfile) || certification.is_a?(ActionDispatch::Http::UploadedFile)
      # ActionDispatch::Http::UploadedFile or similar
      if certification.respond_to?(:original_filename)
        Rails.logger.info "UPLOAD INFO: Filename=#{certification.original_filename}, Content-Type=#{certification.content_type}"
      end
      
      # Create ActiveStorage blob directly for more reliable attachment
      begin
        blob = ActiveStorage::Blob.create_and_upload!(
          io: certification.tempfile,
          filename: certification.original_filename,
          content_type: certification.content_type
        )
        Rails.logger.info "Successfully created blob for medical_certification: #{blob.id}"
        attachment_param = blob.signed_id
      rescue StandardError => e
        Rails.logger.error "Failed to create blob from uploaded file: #{e.message}"
        # Continue with original param as fallback
      end
    elsif certification.is_a?(String) && certification.present?
      # It could be a direct upload signed ID that doesn't match the standard format
      Rails.logger.info "Processing string param for medical certification: #{certification[0..20]}..."
      
      # Check if it might be a signed ID by trying to locate the blob
      begin
        blob = ActiveStorage::Blob.find_signed(certification)
        if blob.present?
          Rails.logger.info "Found blob using signed ID for medical certification: #{blob.id}"
          attachment_param = certification
        end
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        Rails.logger.warn "String is not a valid signed ID: #{certification[0..20]}..."
        attachment_param = certification
      end
    end
    
    # Log pre-attachment info
    Rails.logger.info "PRE-ATTACHMENT CHECK: Application #{id}, medical_certification attached? #{medical_certification.attached?}"
    
    # Get a fresh copy of the application to avoid stale records
    fresh_application = Application.unscoped.find(id)
    fresh_application.medical_certification.attach(attachment_param)
    
    # Verify attachment succeeded
    reload  # Ensure we have the latest data
    
    unless medical_certification.attached?
      # Try one last manual DB query to check if attachment exists
      attachment_exists = ActiveStorage::Attachment.where(
        record_type: 'Application',
        record_id: id,
        name: "medical_certification"
      ).exists?
      
      unless attachment_exists
        Rails.logger.error "Failed to verify medical certification attachment"
        return false
      end
      
      Rails.logger.warn 'Attachment exists in DB but not detected in model - forcing reload'
      medical_certification.reset
    end
    
    Rails.logger.info "Successfully verified medical certification attachment for application #{id}"
    true
  end

def update_certification_attributes(status, verified_by, rejection_reason)
  # Get the previous status for event logging
  previous_status = medical_certification_status
  
  # Prepare the attributes for update
  attrs = {
    medical_certification_status: status,
    medical_certification_verified_at: Time.current
  }
  
  # Only set the verified_by association if it's provided
  attrs[:medical_certification_verified_by_id] = verified_by.id if verified_by.present?
  
  # Add rejection reason if status is 'rejected'
  attrs[:medical_certification_rejection_reason] = rejection_reason if status == 'rejected'
  
  # Update the application
  update!(attrs)
  
  # Create ApplicationStatusChange record to ensure it appears in activity history
  ApplicationStatusChange.create!(
    application: self,
    user: verified_by,
    from_status: previous_status,
    to_status: status,
    metadata: {
      change_type: 'medical_certification',
      submission_method: 'fax',
      verified_at: Time.current.iso8601,
      verified_by_id: verified_by&.id
    }
  )
  
  # Create event for audit trail with clear context
  Event.create!(
    user: verified_by,
    action: 'medical_certification_status_changed',
    metadata: {
      application_id: id,
      old_status: previous_status,
      new_status: status,
      timestamp: Time.current.iso8601,
      change_type: 'medical_certification'
    }
  )
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
