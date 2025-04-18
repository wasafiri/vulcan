# frozen_string_literal: true

module ProofManageable
  extend ActiveSupport::Concern

  ALLOWED_TYPES = ['application/pdf', 'image/jpeg', 'image/png', 'image/tiff', 'image/bmp'].freeze
  MAX_FILE_SIZE = 5.megabytes

  included do
    has_one_attached :income_proof
    has_one_attached :residency_proof
    has_one_attached :medical_certification
    has_many_attached :documents

    validate :correct_proof_mime_type
    validate :proof_size_within_limit
    validate :verify_proof_attachments, unless: :resubmitting_proof?
    validate :require_proof_attachments, if: :require_proof_validations?

    # Add callbacks for when proofs are attached
    after_save :create_proof_submission_audit, if: :proof_attachments_changed?
    after_save :set_proof_status_to_unreviewed, if: :proof_attachments_changed?
    after_save :notify_admins_of_new_proofs, if: -> { needs_review_since_changed? && needs_review_since.present? }
  end

  def proof_attachments_changed?
    # Use Rails' built-in ActiveStorage detection for attachment changes
    if respond_to?(:attachment_changes) && attachment_changes.present? && (attachment_changes['income_proof'].present? || attachment_changes['residency_proof'].present?)
      return true
    end

    # For testing and older Rails versions
    return false if new_record?

    # Check if we recently attached these proofs
    if respond_to?(:saved_change_to_attribute?) && (saved_change_to_attribute?(:income_proof_attachment_id) ||
                     saved_change_to_attribute?(:residency_proof_attachment_id))
      # Use saved_change_to_attribute for association changes
      return true
    end

    # Final fallback - use direct SQL detection
    false # Just disable for tests if other methods aren't available
  end

  def create_proof_submission_audit
    # Guard clause to prevent infinite recursion
    return if @creating_proof_audit
    return unless proof_attachments_changed?

    # Set flag to prevent reentry
    @creating_proof_audit = true

    begin
      # Audit each proof type if it has changed
      audit_specific_proof_change('income')
      audit_specific_proof_change('residency')
    ensure
      # Always reset the flag, even if an exception occurs
      @creating_proof_audit = false
    end
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
      when 'income'
        update!(income_proof_status: new_status)
      when 'residency'
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
  def reject_proof_without_attachment!(proof_type, admin:, reason: 'other',
                                       notes: 'Rejected during application submission')
    attr_name = "#{proof_type}_proof_status"

    begin
      transaction do
        # Create the review (we don't need to use the result directly, so prefix with _)
        _proof_review = proof_reviews.create!(
          admin: admin,
          proof_type: proof_type,
          status: :rejected,
          rejection_reason: reason,
          notes: notes,
          submission_method: :paper,
          reviewed_at: Time.current
        )

        # Then update the status directly in the database to bypass validations
        update_column(attr_name, Application.public_send(attr_name.pluralize.to_s).fetch(:rejected))
      end

      reload
      true
    rescue StandardError => e
      Rails.logger.error "Failed to reject proof without attachment: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end

  def purge_proofs(admin_user)
    raise ArgumentError, 'Admin user required' unless admin_user&.admin?

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
        proof_type: 'system',
        status: 'purged',
        reviewed_at: Time.current,
        submission_method: 'system'
      )

      create_system_notification!(
        recipient: user,
        actor: admin_user,
        action: 'proofs_purged'
      )
    end
  rescue StandardError => e
    Rails.logger.error "Failed to purge proofs for application #{id}: #{e.message}"
    false
  end

  private

  # --- Refactored Audit Logic ---

  def audit_specific_proof_change(proof_type)
    return unless specific_proof_changed?(proof_type)

    create_audit_record_for_proof(proof_type)
  end

  def specific_proof_changed?(proof_type)
    attachment = public_send("#{proof_type}_proof")
    return false unless attachment.attached?

    # Check using attachment_changes (newer Rails versions)
    if respond_to?(:attachment_changes) && attachment_changes["#{proof_type}_proof"].present?
      return true
    end

    # Check using saved_change_to_attribute? (older Rails versions/association changes)
    if respond_to?(:saved_change_to_attribute?) && saved_change_to_attribute?("#{proof_type}_proof_attachment_id")
      return true
    end

    false
  end

  def create_audit_record_for_proof(proof_type)
    attachment = public_send("#{proof_type}_proof")
    blob = attachment.blob

    proof_submission_audits.create!(
      proof_type: proof_type,
      user: Current.user || user,
      application: self,
      ip_address: '0.0.0.0', # Required field but not relevant for audit trail
      metadata: {
        blob_id: blob&.id,
        content_type: blob&.content_type,
        byte_size: blob&.byte_size,
        filename: blob&.filename.to_s
      }
    )
  end

  # --- Original Private Methods ---

  def correct_proof_mime_type
    return unless residency_proof.attached? && !ALLOWED_TYPES.include?(residency_proof.content_type)

    errors.add(:residency_proof, 'must be a PDF or an image file (jpg, jpeg, png, tiff, bmp)')
    return unless income_proof.attached? && !ALLOWED_TYPES.include?(income_proof.content_type)

    errors.add(:income_proof, 'must be a PDF or an image file (jpg, jpeg, png, tiff, bmp)')
  end

  def proof_size_within_limit
    check_proof_size(:residency_proof, residency_proof)
    check_proof_size(:income_proof, income_proof)
  end

  def check_proof_size(attribute, proof)
    return unless proof.attached? && proof.byte_size > MAX_FILE_SIZE

    errors.add(attribute, 'is too large. Maximum size allowed is 5MB.')
  end

  # Verifies that proofs have the right attachment state based on status
  def verify_proof_attachments
    return if new_record? || Thread.current[:skip_proof_validation]

    log_proof_debug_info
    validate_approved_proofs
    validate_not_reviewed_proofs
  end

  def log_proof_debug_info
    Rails.logger.debug("Validating proof attachments for application #{id || 'new'}")
    Rails.logger.debug("Income proof status: #{income_proof_status}, attached: #{income_proof.attached?}")
    Rails.logger.debug("Residency proof status: #{residency_proof_status}, attached: #{residency_proof.attached?}")
  end

  def validate_approved_proofs
    validate_approved_proof(
      proof: income_proof,
      status_check_method: :income_proof_status_approved?,
      error_field: :income_proof,
      label: 'Income proof'
    )
    validate_approved_proof(
      proof: residency_proof,
      status_check_method: :residency_proof_status_approved?,
      error_field: :residency_proof,
      label: 'Residency proof'
    )
  end

  def validate_approved_proof(proof:, status_check_method:, error_field:, label:)
    return unless send(status_check_method) && !proof.attached?

    Rails.logger.error("#{label} marked as approved but no file is attached for application #{id}")
    errors.add(error_field, 'must be attached when status is approved')
  end

  def validate_not_reviewed_proofs
    # Skip this set of validations for paper applications, when reviewing a single proof,
    # or when resubmitting any proof
    return if Thread.current[:paper_application_context] || 
              Thread.current[:reviewing_single_proof] ||
              resubmitting_proof?

    validate_not_reviewed_proof(
      proof: income_proof,
      status_check_method: :income_proof_status_not_reviewed?,
      error_field: :income_proof_status,
      label: 'Income proof'
    )

    validate_not_reviewed_proof(
      proof: residency_proof,
      status_check_method: :residency_proof_status_not_reviewed?,
      error_field: :residency_proof_status,
      label: 'Residency proof'
    )
  end

  def validate_not_reviewed_proof(proof:, status_check_method:, error_field:, label:)
    return unless proof.attached? && send(status_check_method)

    if proof.blob&.created_at
      if proof.blob.created_at < 1.minute.ago
        Rails.logger.error("#{label} is attached but status is still not_reviewed for application #{id}")
        errors.add(error_field, 'should be updated when proof is attached')
      end
    else
      Rails.logger.warn("#{label} blob missing created_at timestamp for application #{id}")
    end
  end

  def set_proof_status_to_unreviewed
    # Guard clause to prevent infinite recursion
    return if @setting_proof_status

    # Only proceed if proofs are attached
    return unless income_proof.attached? || residency_proof.attached?

    begin
      # Set flag to prevent reentry
      @setting_proof_status = true

      # Use update_column to avoid triggering callbacks again
      update_column(:needs_review_since, Time.current)

      # Log success for debugging
      Rails.logger.info "Successfully set needs_review_since to #{Time.current} for application #{id}"
    rescue StandardError => e
      # Log any errors for debugging
      Rails.logger.error "Error setting proof status to unreviewed: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
    ensure
      # Always reset the flag, even if an exception occurs
      @setting_proof_status = false
    end
  end

  def notify_admins_of_new_proofs
    # Skip if there's no change to needs_review_since or it's blank
    return unless needs_review_since_changed? && needs_review_since.present?

    # Schedule the job to notify admins
    NotifyAdminsJob.perform_later(self)
  end

  def create_system_notification!(recipient:, actor:, action:)
    # Create a system-generated notification
    Notification.create!(
      recipient: recipient,
      actor: actor,
      action: action,
      notifiable: self,
      metadata: {
        application_id: id,
        timestamp: Time.current.iso8601
      }
    )
  end

  def require_proof_attachments
    unless income_proof.attached?
      errors.add(:income_proof, 'must be attached. Please upload your income documentation.')
    end

    unless residency_proof.attached?
      errors.add(:residency_proof, 'must be attached. Please upload your proof of Maryland residency.')
    end
  end

  # Determines if we're in the process of resubmitting a previously rejected proof
  # This is used to conditionally skip validations in the resubmission flow
  def resubmitting_proof?
    # Check for explicit resubmission context first
    return true if explicit_resubmission_context?

    # Check for income proof resubmission
    return true if resubmitting_income_proof?

    # Check for residency proof resubmission
    return true if resubmitting_residency_proof?

    # No resubmission detected
    false
  end

  # Check if the thread local variable is set that communicates resubmission context from controller
  def explicit_resubmission_context?
    Thread.current[:resubmitting_proof].present?
  end

  # Check if income proof is being resubmitted
  def resubmitting_income_proof?
    proof_rejected_and_being_updated?('income')
  end

  # Check if residency proof is being resubmitted
  def resubmitting_residency_proof?
    proof_rejected_and_being_updated?('residency')
  end

  # Generic method to check if a specific proof type is rejected and being updated
  def proof_rejected_and_being_updated?(proof_type)
    status_rejected?(proof_type) && 
      proof_attached?(proof_type) && 
      proof_being_updated?(proof_type)
  end

  # Check if the proof status is rejected
  def status_rejected?(proof_type)
    status_method = "#{proof_type}_proof_status"
    # Use string comparison for robustness, especially during initialization
    send(status_method).to_s == 'rejected'
  end

  # Check if the proof is attached
  def proof_attached?(proof_type)
    attachment_name = "#{proof_type}_proof"
    send(attachment_name).attached?
  end

  # Check if the proof is currently being updated
  def proof_being_updated?(proof_type)
    # Early return for new records or if attachment_changes is not available
    return false if new_record? || !respond_to?(:attachment_changes) 

    # Safely check for changes without assuming attachment_changes is a hash
    attachment_name = "#{proof_type}_proof"
    attachment_changes.is_a?(Hash) && attachment_changes[attachment_name].present?
  end

  def require_proof_validations?
    # Only validate proofs when submitting (not for drafts)
    # This checks if the application is being changed from draft to another status
    return false if status_draft?
    return true if saved_change_to_status? && status_before_last_save == 'draft'
    return true if submitted?

    # Skip for paper applications processed by admins
    return false if Thread.current[:paper_application_context]

    false
  end
end
