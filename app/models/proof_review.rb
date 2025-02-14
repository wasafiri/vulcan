class ProofReview < ApplicationRecord
  # Associations
  belongs_to :application
  belongs_to :admin, class_name: "User"

  # Enums
  enum :proof_type, {
    income: 0,
    residency: 1
  }, prefix: true

  enum :status, {
    approved: 0,
    rejected: 1
  }, prefix: true

  enum :submission_method, {
    web: 0,
    email: 1,
    scanned: 2
  }, prefix: true

  # Validations
  validates :proof_type, :status, :reviewed_at, presence: true
  validates :rejection_reason, presence: true, if: :status_rejected?
  validate :admin_must_be_admin_type
  validate :application_must_be_active
  validate :proof_must_be_attached

  # Callbacks
  before_validation :set_reviewed_at, on: :create

  #  after_create :update_application_proof_status

  after_commit :handle_post_review_actions, on: :create

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :by_admin, ->(admin_id) { where(admin_id: admin_id) }
  scope :rejections, -> { where(status: :rejected) }
  scope :last_3_days, -> { where("created_at > ?", 3.days.ago) }

  private

  def set_reviewed_at
    self.reviewed_at ||= Time.current
  end

  def admin_must_be_admin_type
    unless admin&.type == "Admin"
      errors.add(:admin, "must be an administrator")
    end
  end

  def application_must_be_active
    if application&.archived?
      errors.add(:application, "cannot be reviewed when archived")
    end
  end

  def proof_must_be_attached
    proof = case proof_type
    when "income"
      application&.income_proof
    when "residency"
      application&.residency_proof
    end

    unless proof&.attached?
      errors.add(:base, "No #{proof_type} proof found for review")
    end
  end

  def handle_post_review_actions
    if status_rejected?
      Rails.logger.info "Processing proof rejection for Application ID: #{application.id}"
      ActiveRecord::Base.transaction do
        increment_rejections_if_rejected
        send_rejection_notification
        check_max_rejections
      end
    else
      Rails.logger.info "Processing proof approval for Application ID: #{application.id}"
      ActiveRecord::Base.transaction do
        send_approval_notification
      end
    end
  end

  def send_approval_notification
    ApplicationNotificationsMailer.proof_approved(application, self).deliver_now
    Rails.logger.info "Sending proof approval email to User ID: #{application.user.id}"
    Notification.create!(
      recipient: application.user,
      actor: admin,
      action: "proof_approved",
      notifiable: application,
      metadata: {
        proof_type: proof_type
      }
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send approval notification: #{e.message}")
    errors.add(:base, "Failed to send approval notification")
    raise ActiveRecord::Rollback
  end

  def increment_rejections_if_rejected
    application.with_lock do
      application.increment!(:total_rejections)
    end
  rescue ActiveRecord::StaleObjectError => e
    errors.add(:base, "Failed to update rejection count. Please try again. Status: #{e.message}")
    raise ActiveRecord::Rollback
  end

  def send_rejection_notification
    ApplicationNotificationsMailer.proof_rejected(application, self).deliver_now
    Rails.logger.info "Sending proof rejection email to User ID: #{application.user.id}"
    Notification.create!(
      recipient: application.user,
      actor: admin,
      action: "proof_rejected",
      notifiable: application,
      metadata: {
        proof_type: proof_type,
        rejection_reason: rejection_reason
      }
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send rejection notification: #{e.message}")
    errors.add(:base, "Failed to send rejection notification")
    raise ActiveRecord::Rollback
  end

  def check_max_rejections
    application.with_lock do
      if application.total_rejections >= 8
        Notification.create!(
          recipient: User.admins.first,
          actor: admin,
          action: "max_rejections_warning",
          notifiable: application
        )
      end

      if application.total_rejections > 8
        application.update!(status: :archived)
        ApplicationNotificationsMailer.max_rejections_reached(application).deliver_now
      end
    end
  rescue StandardError => e
    Rails.logger.error("Failed to process max rejections: #{e.message}")
    errors.add(:base, "Failed to process rejection limits")
    raise ActiveRecord::Rollback
  end
end
