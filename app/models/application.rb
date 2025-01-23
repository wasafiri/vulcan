class Application < ApplicationRecord
  include ApplicationStatusManagement
  include NotificationDelivery
  include ProofManageable

  # Associations
  belongs_to :user, class_name: "Constituent", foreign_key: :user_id
  belongs_to :income_verified_by, class_name: "User",
    foreign_key: :income_verified_by_id, optional: true
  has_many :training_sessions, class_name: "TrainingSession"
  has_many :trainers, through: :training_sessions
  has_many :evaluations, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_many :proof_reviews, dependent: :destroy

  # Enums
  enum :income_proof_status, {
    not_reviewed: 0,
    approved: 1,
    rejected: 2
  }, prefix: :income_proof_status

  enum :residency_proof_status, {
    not_reviewed: 0,
    approved: 1,
    rejected: 2
  }, prefix: :residency_proof_status

  enum :medical_certification_status, {
    not_requested: 0,
    requested: 1,
    received: 2,
    accepted: 3,
    rejected: 4
  }, prefix: :medical_certification_status

  # Validations
  validates :user, :application_date, :status, presence: true
  validates :maryland_resident, inclusion: { in: [ true ],
    message: "You must be a Maryland resident to apply" }
  validates :terms_accepted, :information_verified, :medical_release_authorized,
    acceptance: { accept: true }, if: :submitted?
  validates :medical_provider_name, :medical_provider_phone, :medical_provider_email,
    presence: true, unless: :draft?
  validates :household_size, :annual_income, presence: true
  validates :self_certify_disability, inclusion: { in: [ true, false ] }
  validates :guardian_relationship, presence: true, if: :is_guardian?

  validate :waiting_period_completed, on: :create

  # Callbacks
  after_update :schedule_admin_notifications, if: :needs_proof_review?
  after_update :log_status_change, if: :saved_change_to_status?

  # Scopes
  scope :search_by_last_name, ->(query) {
    includes(:user, :proof_reviews, :training_sessions, :evaluations)
      .where("users.last_name ILIKE ?", "%#{query}%")
      .references(:users)
  }
  scope :needs_review, -> { where(status: :needs_information) }
  scope :incomplete, -> { where(status: :in_progress) }
  scope :complete, -> { where(status: :approved) }
  scope :needs_evaluation, -> { where(status: :approved) }
  scope :needs_training, -> { where(status: :approved) }
  scope :needs_income_review, -> { where(income_proof_status: :not_reviewed) }
  scope :needs_residency_review, -> { where(residency_proof_status: :not_reviewed) }
  scope :rejected_income_proofs, -> { where(income_proof_status: :rejected) }
  scope :rejected_residency_proofs, -> { where(residency_proof_status: :rejected) }

  # Status methods moved from controller
  def approve!
    with_lock do
      update!(status: :approved)
    end
  rescue => e
    Rails.logger.error "Failed to approve application #{id}: #{e.message}"
    false
  end

  def reject!
    with_lock do
      update!(status: :rejected)
    end
  rescue => e
    Rails.logger.error "Failed to reject application #{id}: #{e.message}"
    false
  end

  def request_documents!
    update!(status: :awaiting_documents)
  end

  def self.batch_update_status(ids, status)
    transaction do
      where(id: ids).lock("FOR UPDATE SKIP LOCKED").find_each do |application|
        unless application.update(status: status)
          Rails.logger.error(
            "Failed to update application #{application.id}: #{application.errors.full_messages}"
          )
          raise ActiveRecord::Rollback
        end
      end
      true
    rescue => e
      Rails.logger.error "Batch update failed: #{e.message}"
      false
    end
  end

  # Evaluator assignment
  def assign_evaluator!(evaluator)
    with_lock do  # with_lock already wraps in a transaction
      evaluation = evaluations.create!(
        evaluator: evaluator,
        constituent: user,
        status: :pending,
        evaluation_type: determine_evaluation_type,
        evaluation_date: Date.current
      )
      # Notification queued inside the same transaction
      EvaluatorMailer.with(
        evaluation: evaluation,
        constituent: user
      ).new_evaluation_assigned.deliver_later
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to assign evaluator: #{e.message}"
    false
  end

  # Certification management
  def update_certification!(certification:, status:, verified_by:)
    with_lock do  # Simpler than nested transaction/lock blocks
      medical_certification.attach(certification) if certification.present?

      update!(
        medical_certification_status: status,
        medical_certification_verified_at: Time.current,
        medical_certification_verified_by: verified_by
      )
      true
    end
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to update certification: #{e.message}"
    false
  end

  def schedule_training!(trainer:, scheduled_for:)
    with_lock do
      training_sessions.create!(
        trainer: trainer,
        scheduled_for: scheduled_for,
        status: :scheduled
      )
    end
    true
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error "[Application #{id}] Failed to schedule training: #{e.message}"
    errors.add(:base, e.message)
    false
  end

  def latest_evaluation
    evaluations.order(created_at: :desc).first
  end

  private

  def log_status_change
    Event.create!(
      user: Current.user,
      action: "application_status_changed",
      metadata: {
        application_id: id,
        old_status: status_before_last_save,
        new_status: status,
        timestamp: Time.current.iso8601
      }
    )
  end

  def schedule_admin_notifications
    NotifyAdminsJob.perform_later(self)
  end

  def determine_evaluation_type
    user.evaluations.exists? ? :follow_up : :initial
  end

  def waiting_period_completed
    return unless user
    return if new_record?

    last_application = user.applications.where.not(id: id)
                          .order(application_date: :desc).first
    return unless last_application

    waiting_period = Policy.get("waiting_period_years") || 3

    if last_application.application_date > waiting_period.years.ago
      errors.add(:base, "You must wait #{waiting_period} years before submitting a new application.")
    end
  end

  def needs_proof_review?
    saved_change_to_needs_review_since? && needs_review_since.present?
  end

  def notify_admins_of_new_proofs
    notifications = User.where(type: "Admin").map do |admin|
      {
        recipient_id: admin.id,
        actor_id: user.id,
        action: "proof_submitted",
        notifiable_type: self.class.name,
        notifiable_id: id,
        metadata: { proof_types: pending_proof_types }
      }
    end
    Notification.insert_all!(notifications) # Use bulk insert
  end

  def pending_proof_types
    types = []
    types << "income" if income_proof_status_not_reviewed?
    types << "residency" if residency_proof_status_not_reviewed?
    types
  end

  def create_system_notification!(recipient:, actor:, action:)
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

  def is_guardian?
    user&.is_guardian == true
  end
end
