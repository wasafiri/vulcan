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

  def set_proof_status_to_unreviewed
    update(needs_review_since: Time.current) if income_proof.attached? || residency_proof.attached?
  end
end
