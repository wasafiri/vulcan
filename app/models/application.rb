# frozen_string_literal: true

# Represents a constituent's application in the system
# Manages the application lifecycle including proof submission, review,
# medical certification, training sessions, evaluations, and voucher issuance
class Application < ApplicationRecord
  delegate :guardian_relationship, :guardian_relationship=, to: :user, allow_nil: true

  # Concerns
  include ApplicationStatusManagement
  include NotificationDelivery
  include ProofManageable
  include ProofConsistencyValidation
  include CertificationManagement
  include VoucherManagement
  include TrainingManagement
  include EvaluationManagement

  # Associations - made more flexible to work with both Constituent and Users::Constituent
  belongs_to :user, -> { where("type = 'Users::Constituent' OR type = 'Constituent'") }, 
             class_name: 'User', 
             foreign_key: :user_id, 
             inverse_of: :applications
  belongs_to :income_verified_by,
             class_name: 'User',
             foreign_key: :income_verified_by_id,
             optional: true,
             inverse_of: :income_verified_applications
  has_many :training_sessions, class_name: 'TrainingSession'
  has_many :trainers, through: :training_sessions
  has_many :evaluations, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_many :proof_reviews, dependent: :destroy
  has_many :status_changes, class_name: 'ApplicationStatusChange'
  has_many :proof_submission_audits, dependent: :destroy
  has_many :vouchers, dependent: :restrict_with_error
  has_many :application_notes, dependent: :destroy
  has_and_belongs_to_many :products
  has_one_attached :medical_certification
  belongs_to :medical_certification_verified_by,
             class_name: 'User',
             optional: true,
             inverse_of: :medical_certification_verified_applications

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
  validates :maryland_resident, inclusion: { in: [true],
                                             message: 'You must be a Maryland resident to apply' }
  validates :terms_accepted, :information_verified, :medical_release_authorized,
            acceptance: { accept: true }, if: :submitted?
  validates :medical_provider_name, :medical_provider_phone, :medical_provider_email,
            presence: true, unless: :status_draft?
  validates :household_size, :annual_income, presence: true
  validates :self_certify_disability, inclusion: { in: [true, false] }
  validates :guardian_relationship, presence: true, if: :is_guardian?

  validate :waiting_period_completed, on: :create
  validate :constituent_must_have_disability, if: :validate_disability?

  # Callbacks
  after_update :log_status_change, if: :saved_change_to_status?

  # Scopes
  scope :search_by_last_name, lambda { |query|
    includes(:user, :proof_reviews, :training_sessions, :evaluations)
      .where('users.last_name ILIKE ?', "%#{query}%")
      .references(:users)
  }

  # Base scope for approved applications
  scope :approved, -> { where(status: :approved) }

  # Alias scopes for approved applications
  scope :complete, -> { approved }
  scope :needs_evaluation, -> { approved }
  scope :needs_training, -> { approved }

  scope :needs_income_review, -> { where(income_proof_status: :not_reviewed) }
  scope :needs_residency_review, -> { where(residency_proof_status: :not_reviewed) }
  scope :rejected_income_proofs, -> { where(income_proof_status: :rejected) }
  scope :rejected_residency_proofs, -> { where(residency_proof_status: :rejected) }
  scope :with_pending_training, lambda {
    joins(:training_sessions).merge(TrainingSession.where(status: %i[requested scheduled confirmed])).distinct
  }
  scope :assigned_to_trainer, lambda { |trainer_id|
    joins(:training_sessions).where(training_sessions: { trainer_id: trainer_id }).distinct
  }
  scope :with_active_training_for_trainer, lambda { |trainer_id|
    joins(:training_sessions).where(
      training_sessions: {
        trainer_id: trainer_id,
        status: %i[scheduled confirmed]
      }
    ).distinct
  }

  # Status methods - using the robust implementation from the class (with events and voucher creation)
  # (Note: these override the simpler implementations from ApplicationStatusManagement)
  def approve!
    with_lock do
      update!(status: :approved)

      # Create event for approval
      Event.create!(
        user: Current.user,
        action: 'application_approved',
        metadata: {
          application_id: id,
          timestamp: Time.current.iso8601
        }
      )

      # Create initial voucher
      create_initial_voucher if can_create_voucher?
    end
  rescue StandardError => e
    Rails.logger.error "Failed to approve application #{id}: #{e.message}"
    false
  end

  def reject!
    with_lock do
      update!(status: :rejected)
    end
  rescue StandardError => e
    Rails.logger.error "Failed to reject application #{id}: #{e.message}"
    false
  end

  def request_documents!
    with_lock do
      update!(status: :awaiting_documents)
      Notification.create!(
        recipient: user,
        actor: Current.user,
        action: 'documents_requested',
        notifiable: self
      )
    end
  end

  def constituent_full_name
    # Checking if user exists and has both names to avoid nil errors
    if user && (user.first_name || user.last_name)
      "#{user.first_name} #{user.last_name}".strip
    else
      'Unknown Constituent'
    end
  end

  # Determines if the proof needs review based on submission history
  # @param proof_type [String] The type of proof ("income" or "residency")
  # @return [Boolean] True if there's a new submission requiring review
  def needs_proof_type_review?(proof_type)
    latest_review = proof_reviews.where(proof_type: proof_type).order(created_at: :desc).first
    latest_audit = proof_submission_audits.where(proof_type: proof_type).order(created_at: :desc).first
    
    # Case 1: No reviews yet, but has submission
    return true if latest_review.nil? && latest_audit.present?
    
    # Case 2: Has a new submission after the last review
    return latest_audit.present? && latest_review.present? && latest_audit.created_at > latest_review.created_at
  end

  # Determines the appropriate proof review button text based on proof status
  # @param proof_type [String] The type of proof ("income" or "residency")
  # @return [String] The appropriate button text
  def proof_review_button_text(proof_type)
    latest_review = proof_reviews.where(proof_type: proof_type).order(created_at: :desc).first
    latest_audit = proof_submission_audits.where(proof_type: proof_type).order(created_at: :desc).first

    if latest_review&.status_rejected?
      if latest_audit && latest_audit.created_at > latest_review.created_at
        'Review Resubmitted Proof'
      else
        'Review Rejected Proof'
      end
    else
      'Review Proof'
    end
  end

  # Determines the appropriate CSS classes for the proof review button
  # @param proof_type [String] The type of proof ("income" or "residency")
  # @return [String] The appropriate CSS class string for the button
  def proof_review_button_class(proof_type)
    latest_review = proof_reviews.where(proof_type: proof_type).order(created_at: :desc).first
    latest_audit = proof_submission_audits.where(proof_type: proof_type).order(created_at: :desc).first

    if latest_review&.status_rejected?
      if latest_audit && latest_audit.created_at > latest_review.created_at
        # Resubmitted proof - keep blue
        'bg-blue-600 hover:bg-blue-700'
      else
        # Rejected proof - use red
        'bg-red-600 hover:bg-red-700'
      end
    else
      # Initial review - keep blue
      'bg-blue-600 hover:bg-blue-700'
    end
  end

  # Application status change tracking
  def update_status(new_status, user: nil, notes: nil)
    old_status = status
    return unless update(status: new_status)

    status_changes.create!(
      from_status: old_status,
      to_status: new_status,
      user: user,
      notes: notes
    )
  end

  def medical_provider_name
    self[:medical_provider_name]
  end

  private

  def log_status_change
    # Guard clause to prevent infinite recursion
    return if @logging_status_change

    acting_user = Current.user || user
    return unless acting_user

    @logging_status_change = true

    begin
      Event.create!(
        user: acting_user,
        action: 'application_status_changed',
        metadata: {
          application_id: id,
          old_status: status_before_last_save,
          new_status: status,
          submission_method: submission_method,
          timestamp: Time.current.iso8601
        }
      )
    rescue StandardError => e
      Rails.logger.error "Failed to log status change for application #{id}: #{e.message}"
    ensure
      @logging_status_change = false
    end
  end

  def schedule_admin_notifications
    return if Rails.env.test?
    return unless needs_review_since_changed? && needs_review_since.present?

    NotifyAdminsJob.perform_later(self)
  end

  def waiting_period_completed
    return unless user && !new_record?

    last_app = user_applications_except_current
    return unless last_app

    waiting_period = Policy.get('waiting_period_years') || 3
    if last_app.application_date > waiting_period.years.ago
      errors.add(:base, "You must wait #{waiting_period} years before submitting a new application.")
    end
  end

  def user_applications_except_current
    user.applications.where.not(id: id).order(application_date: :desc).first
  end

  def needs_proof_review?
    saved_change_to_needs_review_since? && needs_review_since.present?
  end

  def notify_admins_of_new_proofs
    return unless user

    admin_ids = User.where(type: 'Users::Administrator').pluck(:id)
    return if admin_ids.empty?

    notifications = admin_ids.map do |admin_id|
      {
        recipient_id: admin_id,
        actor_id: user.id,
        action: 'proof_submitted',
        notifiable_type: self.class.name,
        notifiable_id: id,
        metadata: { proof_types: pending_proof_types }
      }
    end

    Notification.insert_all!(notifications)
  end

  def pending_proof_types
    types = []
    types << 'income' if income_proof_status_not_reviewed?
    types << 'residency' if residency_proof_status_not_reviewed?
    types
  end

  def is_guardian?
    user&.is_guardian == true
  end

  def constituent_must_have_disability
    return if user&.has_disability_selected?

    errors.add(:base, 'At least one disability must be selected before submitting an application.')
  end

  def validate_disability?
    return false if status_draft?
    return true if saved_change_to_status? && status_before_last_save == 'draft'
    return true if submitted?

    false
  end
end
