module ProofManageable
  extend ActiveSupport::Concern

  ALLOWED_TYPES = [ "application/pdf", "image/jpeg", "image/png", "image/tiff", "image/bmp" ].freeze
  MAX_FILE_SIZE = 5.megabytes

  included do
    has_one_attached :income_proof
    has_one_attached :residency_proof
    has_one_attached :medical_certification
    has_many_attached :documents

    validate :correct_proof_mime_type
    validate :proof_size_within_limit
    validate :verify_proof_attachments
  end

  def all_proofs_approved?
    income_proof_status_approved? && residency_proof_status_approved?
  end

  def rejected_income_proof?
    income_proof_status_rejected?
  end

  def rejected_residency_proof?
    residency_proof_status_rejected?
  end

  def can_submit_proof?
    # An application can submit proof if it's in a valid state
    # This is a placeholder implementation - adjust based on your business logic
    true
  end

  def update_proof_status!(proof_type, new_status)
    transaction do
      case proof_type
      when "income"
        update!(income_proof_status: new_status)
      when "residency"
        update!(residency_proof_status: new_status)
      else
        raise ArgumentError, "Invalid proof type: #{proof_type}"
      end
    end
    true
  rescue ActiveRecord::RecordInvalid, ArgumentError => e
    Rails.logger.error "Failed to update proof status: #{e.message}"
    false
  end
  
  # Special method for updating to rejected status that bypasses validations
  # This is needed for paper applications where we reject without attachment
  def reject_proof_without_attachment!(proof_type, admin:, reason: 'other', notes: 'Rejected during application submission')
    attr_name = "#{proof_type}_proof_status"
    
    begin
      transaction do
        # First create the review
        proof_review = proof_reviews.create!(
          admin: admin,
          proof_type: proof_type,
          status: :rejected,
          rejection_reason: reason,
          notes: notes,
          submission_method: :paper,
          reviewed_at: Time.current
        )
        
        # Then update the status directly in the database to bypass validations
        # This is key - we use update_column to skip validations that would otherwise
        # prevent rejected proofs without attachments
        update_column(attr_name, Application.public_send("#{attr_name.pluralize}").fetch(:rejected))
      end
      
      # Reload to get latest state
      reload
      
      # If we reached here, there was no exception, so return true
      return true
      
    rescue => e
      Rails.logger.error "Failed to reject proof without attachment: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return false
    end
  end

  def purge_proofs(admin_user)
    raise ArgumentError, "Admin user required" unless admin_user&.admin?

    transaction do
      income_proof.purge if income_proof.attached?
      residency_proof.purge if residency_proof.attached?

      update_columns(
        income_proof_status: :not_reviewed,
        residency_proof_status: :not_reviewed,
        last_proof_submitted_at: nil,
        needs_review_since: nil
      )

      proof_reviews.create!(
        admin: admin_user,
        proof_type: "system",
        status: "purged",
        reviewed_at: Time.current,
        submission_method: "system"
      )

      create_system_notification!(
        recipient: user,
        actor: admin_user,
        action: "proofs_purged"
      )
    end
  rescue => e
    Rails.logger.error "Failed to purge proofs for application #{id}: #{e.message}"
    false
  end

  private

  def correct_proof_mime_type
    if residency_proof.attached? && !ALLOWED_TYPES.include?(residency_proof.content_type)
      errors.add(:residency_proof, "must be a PDF or an image file (jpg, jpeg, png, tiff, bmp)")
    end

    if income_proof.attached? && !ALLOWED_TYPES.include?(income_proof.content_type)
      errors.add(:income_proof, "must be a PDF or an image file (jpg, jpeg, png, tiff, bmp)")
    end
  end

  def proof_size_within_limit
    if residency_proof.attached? && residency_proof.byte_size > MAX_FILE_SIZE
      errors.add(:residency_proof, "is too large. Maximum size allowed is 5MB.")
    end

    if income_proof.attached? && income_proof.byte_size > MAX_FILE_SIZE
      errors.add(:income_proof, "is too large. Maximum size allowed is 5MB.")
    end
  end
  
  # Verifies that proofs have the right attachment state based on status
  def verify_proof_attachments
    # Skip validation for new records - validation will happen when they're saved
    return if new_record?
    
    # This validation runs for ALL applications, including paper applications
    # Log current state for diagnostics
    Rails.logger.debug("Validating proof attachments for application #{id || 'new'}")
    Rails.logger.debug("Income proof status: #{income_proof_status}, attached: #{income_proof.attached?}")
    Rails.logger.debug("Residency proof status: #{residency_proof_status}, attached: #{residency_proof.attached?}")
    
    # Check approved proofs - they must have an attachment
    if income_proof_status_approved? && !income_proof.attached?
      # Log the error for debugging purposes
      Rails.logger.error("Income proof marked as approved but no file is attached for application #{id}")
      errors.add(:income_proof, "must be attached when status is approved")
    end
    
    if residency_proof_status_approved? && !residency_proof.attached?
      # Log the error for debugging purposes
      Rails.logger.error("Residency proof marked as approved but no file is attached for application #{id}")
      errors.add(:residency_proof, "must be attached when status is approved")
    end
    
    # For non-paper applications, check that attached proofs have appropriate status
    # (Skip this validation during paper application submission)
    unless Thread.current[:paper_application_context]
      if income_proof.attached? && income_proof_status_not_reviewed?
        # Only add error if it's not a brand new attachment 
        # This allows for the initial attachment which will be marked as not_reviewed
        if income_proof.blob.created_at < 1.minute.ago
          Rails.logger.error("Income proof is attached but status is still not_reviewed for application #{id}")
          errors.add(:income_proof_status, "should be updated when proof is attached")
        end
      end
      
      if residency_proof.attached? && residency_proof_status_not_reviewed?
        # Only add error if it's not a brand new attachment
        if residency_proof.blob.created_at < 1.minute.ago
          Rails.logger.error("Residency proof is attached but status is still not_reviewed for application #{id}")
          errors.add(:residency_proof_status, "should be updated when proof is attached")
        end
      end
    end
    
    # We deliberately do NOT validate attachments for rejected proofs
    # This is because paper applications can be rejected without any file attachment
    # In the case of paper applications, the rejection happens at the point of submission
    # For online applications, the rejected proof may still have an attachment, but it's not required
  end

  def set_proof_status_to_unreviewed
    update(needs_review_since: Time.current) if income_proof.attached? || residency_proof.attached?
  end
end
