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
    after_save :purge_proof_if_rejected # Add the purge callback
  end

  def proof_attachments_changed?
    # Use Rails' built-in ActiveStorage detection for attachment changes
    if respond_to?(:attachment_changes) && attachment_changes.present? &&
       (attachment_changes['income_proof'].present? || attachment_changes['residency_proof'].present?)
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
    false # Disable for tests if other methods aren't available
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
      # Reset the flag, even if an exception occurs
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
    # An application can submit proof if it's in a valid state - adjust this placeholder based on your business logic
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

  # This is needed for paper applications where we reject without attachment to avoid uploading docs we know to be invalid
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

        # Update the status, relying on the calling context (e.g., paper application) to skip attachment validations.
        update!(attr_name => :rejected)
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

    begin
      Thread.current[:skip_proof_validation] = true
      transaction do
        income_proof.purge if income_proof.attached?
        residency_proof.purge if residency_proof.attached?

        update!(
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
    ensure
      Thread.current[:skip_proof_validation] = false
    end
  end

  # Method called explicitly by ProofReviewer to purge a proof after status is set to rejected
  def purge_rejected_proof(proof_type_key)
    attachment_name = :"#{proof_type_key}_proof"
    attachment = public_send(attachment_name)

    if attachment.attached?
      Rails.logger.info "[ProofManageable][purge_rejected_proof] Purging #{attachment_name} for App ##{id}."
      attachment.purge_later
    else
      Rails.logger.info "[ProofManageable][purge_rejected_proof] Skipping purge for #{attachment_name} on App ##{id} - not attached."
    end
  end

  # Purges the relevant proof attachment if its status was just saved as rejected.
  # Uses saved_change_to_attribute? which checks the most recent save operation.
  # NOTE: This callback might still be useful for other save operations, but not for ProofReviewer updates.
  def purge_proof_if_rejected
    # Purge income proof if it was just saved as rejected
    if saved_change_to_income_proof_status? && income_proof_status_rejected? && income_proof.attached?
      Rails.logger.info "[ProofManageable][purge] Purging income proof for App ##{id} due to status saved as rejected."
      income_proof.purge_later
    else
      Rails.logger.info "[ProofManageable][purge] Skipping income proof purge for App ##{id}. Saved change? #{saved_change_to_income_proof_status?}, Rejected? #{income_proof_status_rejected?}, Attached? #{income_proof.attached?}"
    end

    # Purge residency proof if it was just saved as rejected
    if saved_change_to_residency_proof_status? && residency_proof_status_rejected? && residency_proof.attached?
      Rails.logger.info "[ProofManageable][purge] Purging residency proof for App ##{id} due to status saved as rejected."
      residency_proof.purge_later
    else
      Rails.logger.info "[ProofManageable][purge] Skipping residency proof purge for App ##{id}. Saved change? #{saved_change_to_residency_proof_status?}, Rejected? #{residency_proof_status_rejected?}, Attached? #{residency_proof.attached?}"
    end
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
    return true if respond_to?(:attachment_changes) && attachment_changes["#{proof_type}_proof"].present?

    # Check using saved_change_to_attribute? (older Rails versions/association changes)
    return true if respond_to?(:saved_change_to_attribute?) && saved_change_to_attribute?("#{proof_type}_proof_attachment_id")

    false
  end

  def create_audit_record_for_proof(proof_type)
    attachment = public_send("#{proof_type}_proof")
    blob = attachment.blob
    actor = Current.user || user

    AuditEventService.log(
      action: "#{proof_type}_proof_submitted",
      actor: actor,
      auditable: self,
      metadata: {
        proof_type: proof_type,
        blob_id: blob&.id,
        content_type: blob&.content_type,
        byte_size: blob&.byte_size,
        filename: blob&.filename.to_s,
        ip_address: Current.ip_address,
        user_agent: Current.user_agent
      }
    )
  end

  # --- Original Private Methods ---

  def correct_proof_mime_type
    # Check residency proof
    if residency_proof.attached? && ALLOWED_TYPES.exclude?(residency_proof.content_type)
      errors.add(:residency_proof, 'must be a PDF or an image file (jpg, jpeg, png, tiff, bmp)')
    end

    # Check income proof independently
    return unless income_proof.attached? && ALLOWED_TYPES.exclude?(income_proof.content_type)

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
    # --- DEBUG LOGGING ---
    Rails.logger.debug do
      "[ProofManageable] Checking verify_proof_attachments. Paper context: #{Thread.current[:paper_application_context].inspect}"
    end
    # --- END DEBUG ---

    # Skip for new records, explicit skips, OR during paper application processing
    if new_record? || Thread.current[:skip_proof_validation] || Thread.current[:paper_application_context]
      Rails.logger.debug '[ProofManageable] Skipping verify_proof_attachments.'
      return
    end

    log_proof_debug_info
    validate_approved_proofs
    validate_not_reviewed_proofs
  end

  def log_proof_debug_info
    Rails.logger.debug { "Validating proof attachments for application #{id || 'new'}" }
    Rails.logger.debug { "Income proof status: #{income_proof_status}, attached: #{income_proof.attached?}" }
    Rails.logger.debug { "Residency proof status: #{residency_proof_status}, attached: #{residency_proof.attached?}" }
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

    Rails.logger.debug { "#{label} marked as approved but no file is attached for application #{id}" }
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

      # Use update! to run validations and trigger necessary callbacks.
      # The `if` conditions on other callbacks and the `@setting_proof_status` guard prevent infinite loops.
      update!(needs_review_since: Time.current)

      # Log success for debugging
      Rails.logger.info "Successfully set needs_review_since to #{needs_review_since} for application #{id}"
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
    # Use NotificationService for centralized notification creation
    NotificationService.create_and_deliver!(
      type: action,
      recipient: recipient,
      actor: actor,
      notifiable: self,
      metadata: {
        application_id: id,
        timestamp: Time.current.iso8601
      },
      channel: :email
    )
  end

  def require_proof_attachments
    errors.add(:income_proof, 'must be attached. Please upload your income documentation.') unless income_proof.attached?

    return if residency_proof.attached?

    errors.add(:residency_proof, 'must be attached. Please upload your proof of Maryland residency.')
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
    Rails.logger.debug do
      "[ProofManageable] Checking require_proof_validations?. Paper context: #{Thread.current[:paper_application_context].inspect}"
    end

    # Skip for administrative actions like purging proofs
    return false if Thread.current[:skip_proof_validation]

    # Skip for paper applications processed by admins - CHECK THIS FIRST
    return false if Thread.current[:paper_application_context]

    # Skip validation for new records (attachments handled by AS on initial save)
    return false if new_record?
    # Skip validation for drafts
    return false if status_draft?
    # Validate when transitioning from draft or already submitted
    return true if saved_change_to_status? && status_before_last_save == 'draft'
    return true if submitted?

    false
  end
end
