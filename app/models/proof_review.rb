# Manages the review process for income and residency proof documents
class ProofReview < ApplicationRecord
  # Associations
  belongs_to :application
  belongs_to :admin, class_name: 'User'

  # Enums (using the original syntax to avoid argument errors)
  enum :proof_type, { income: 0, residency: 1 }, prefix: true
  enum :status, { approved: 0, rejected: 1 }, prefix: true
  enum :submission_method, { web: 0, email: 1, scanned: 2, paper: 3 }, prefix: true

  # Validations
  validates :proof_type, :status, :reviewed_at, presence: true
  validates :rejection_reason, presence: true, if: :status_rejected?
  validate :admin_must_be_admin_type
  validate :application_must_be_active
  validate :proof_must_be_attached, if: :should_validate_proof_attachment?

  # Callbacks
  before_validation :set_reviewed_at, on: :create
  after_commit :handle_post_review_actions, on: :create
  after_commit :check_all_proofs_approved, on: :create, if: :status_approved?

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_admin, ->(admin_id) { where(admin_id: admin_id) }
  scope :rejections, -> { where(status: :rejected) }
  scope :last_3_days, -> { where('created_at > ?', 3.days.ago) }

  private

  def set_reviewed_at
    self.reviewed_at ||= Time.current
  end

  def admin_must_be_admin_type
    errors.add(:admin, 'must be an administrator') unless admin&.type == 'Admin'
  end

  def application_must_be_active
    errors.add(:application, 'cannot be reviewed when archived') if application&.archived?
  end

  def should_validate_proof_attachment?
    # Only validate proof attachment in production or when explicitly testing this validation
    return false if Rails.env.test? && ENV['VALIDATE_PROOF_ATTACHMENTS'] != 'true'

    # Always validate in production
    return true if Rails.env.production?

    # In other environments, validate based on the proof type and status
    # For example, we might want to validate for approved proofs but not for rejected ones
    return true if status_approved?

    # For rejected proofs, we might want to be more lenient in development/test
    return false if status_rejected? && (Rails.env.development? || Rails.env.test?)

    # For paper submissions with rejected proofs, we don't need to validate
    # since the admin might be rejecting a proof that wasn't provided
    return false if status_rejected? && submission_method_paper?

    # Default to validating
    true
  end

  def proof_must_be_attached
    proof = case proof_type
            when 'income' then application&.income_proof
            when 'residency' then application&.residency_proof
            end
    errors.add(:base, "No #{proof_type} proof found for review") unless proof&.attached?
  end

  def handle_post_review_actions
    Rails.logger.info "Starting handle_post_review_actions for ProofReview ID: #{id}"
    Rails.logger.info "Initial status check - status: #{status.inspect}, blank?: #{status.blank?}"
    return if status.blank?

    Rails.logger.info "Processing proof review for Application ID: #{application.id}"
    Rails.logger.info "Status details: raw: #{status.inspect}, before type cast: #{status_before_type_cast.inspect}, rejected?: #{status_rejected?}"

    begin
      ActiveRecord::Base.transaction do
        if status_rejected?
          Rails.logger.info 'Status is rejected, handling rejection flow'
          increment_rejections_if_rejected
          check_max_rejections
        else
          Rails.logger.info 'Status is approved, skipping rejection flow'
        end
      end

      # Send appropriate notification based on status
      if status_rejected?
        send_notification('proof_rejected', :proof_rejected, { proof_type: proof_type, rejection_reason: rejection_reason })
      else
        send_notification('proof_approved', :proof_approved, { proof_type: proof_type })
      end
    rescue StandardError => e
      Rails.logger.error "Failed to process proof review actions: #{e.message}\n#{e.backtrace.join("\n")}"
      raise
    end
  end

  # DRY method to create a notification record and send the email
  def send_notification(action_name, mail_method, metadata)
    notification = Notification.create!(
      recipient: application.user,
      actor: admin,
      action: action_name,
      notifiable: application,
      metadata: metadata
    )
    Rails.logger.info "Created notification ID: #{notification.id}"

    mail = ApplicationNotificationsMailer.send(mail_method, application, self)
    Rails.logger.info "Generated mail with subject: #{mail.subject}"
    mail.deliver_now
    Rails.logger.info "Successfully sent #{action_name} email to User ID: #{application.user.id}"
  rescue StandardError => e
    Rails.logger.error "Failed to send #{action_name} email: #{e.message}\n#{e.backtrace.join("\n")}"
    raise
  end

  def increment_rejections_if_rejected
    application.with_lock do
      application.increment!(:total_rejections)
    end
  rescue StandardError => e
    errors.add(:base, "Failed to update rejection count. Please try again. Status: #{e.message}")
    raise ActiveRecord::Rollback
  end

  def check_max_rejections
    application.with_lock do
      if application.total_rejections >= 8
        Notification.create!(
          recipient: User.admins.first,
          actor: admin,
          action: 'max_rejections_warning',
          notifiable: application
        )
      end
      if application.total_rejections > 8
        application.update!(status: :archived)
        ApplicationNotificationsMailer.max_rejections_reached(application).deliver_now
      end
    end
  rescue StandardError => e
    Rails.logger.error "Failed to process max rejections: #{e.message}"
    errors.add(:base, 'Failed to process rejection limits')
    raise ActiveRecord::Rollback
  end

  def check_all_proofs_approved
    # Reload the application to ensure we have the latest status
    application.reload

    # Check if all proofs are approved and certification not already requested
    if application.all_proofs_approved? && !application.medical_certification_status_requested?
      Rails.logger.info "All proofs approved for Application ID: #{application.id}, sending medical provider email"

      # Update certification status and send email
      application.with_lock do
        application.update!(medical_certification_status: :requested)
        # Use deliver_later to enqueue a job
        MedicalProviderMailer.request_certification(application).deliver_later
      end
    end
  rescue StandardError => e
    Rails.logger.error "Failed to process all proofs approved: #{e.message}\n#{e.backtrace.join("\n")}"
  end
end
