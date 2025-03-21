class Application < ApplicationRecord
  delegate :guardian_relationship, :guardian_relationship=, to: :user, allow_nil: true
  include ApplicationStatusManagement
  include NotificationDelivery
  include ProofManageable
  include ProofConsistencyValidation

  # Associations
  belongs_to :user, class_name: 'Constituent', foreign_key: :user_id
  belongs_to :income_verified_by,
             class_name: 'User',
             foreign_key: :income_verified_by_id, 
             optional: true
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
             optional: true

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
  validates :self_certify_disability, inclusion: { in: [ true, false ] }
  validates :guardian_relationship, presence: true, if: :is_guardian?

  validate :waiting_period_completed, on: :create
  validate :constituent_must_have_disability, if: :validate_disability?
  validate :proof_status_consistency
  validate :proof_attachment_integrity

  # Callbacks - disable admin notifications in tests to avoid recursion
  # We'll use the one defined in ProofManageable concern instead
  # after_update :schedule_admin_notifications, if: :needs_proof_review?  
  after_update :log_status_change, if: :saved_change_to_status?

  # Scopes
  scope :search_by_last_name, ->(query) {
    includes(:user, :proof_reviews, :training_sessions, :evaluations)
      .where('users.last_name ILIKE ?', "%#{query}%")
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
  scope :with_pending_training, -> {
    joins(:training_sessions).merge(TrainingSession.where(status: [:requested, :scheduled, :confirmed])).distinct
  }
  
  # Scope for applications assigned to a specific trainer
  scope :assigned_to_trainer, ->(trainer_id) {
    joins(:training_sessions).where(training_sessions: { trainer_id: trainer_id }).distinct
  }
  
  # Scope for applications with active training sessions for a specific trainer
  scope :with_active_training_for_trainer, ->(trainer_id) {
    joins(:training_sessions).where(
      training_sessions: { 
        trainer_id: trainer_id,
        status: [:scheduled, :confirmed]
      }
    ).distinct
  }

  # Status methods moved from controller
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

  def assign_voucher!(assigned_by: nil)
    return false unless can_create_voucher?

    with_lock do
      voucher = vouchers.create!
      Event.create!(
        user: assigned_by || Current.user,
        action: 'voucher_assigned',
        metadata: {
          application_id: id,
          voucher_id: voucher.id,
          voucher_code: voucher.code,
          initial_value: voucher.initial_value,
          timestamp: Time.current.iso8601
        }
      )

      # Notify constituent
      create_system_notification!(
        recipient: user,
        actor: assigned_by || Current.user,
        action: 'voucher_assigned'
      )

      voucher
    end
  rescue StandardError => e
    Rails.logger.error "Failed to assign voucher for application #{id}: #{e.message}"
    false
  end

  def can_create_voucher?
    status_approved? &&
      medical_certification_status_accepted? &&
      !vouchers.exists?
  end

  def create_initial_voucher
    return unless can_create_voucher?

    assign_voucher!(assigned_by: Current.user)
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

  def assign_evaluator!(evaluator)
    with_lock do
      evaluation = evaluations.create!(
        evaluator: evaluator,
        constituent: user,
        application: self,
        evaluation_type: determine_evaluation_type,
        evaluation_datetime: nil, # Will be set when scheduling
        needs: '',
        location: ''
        # Initialize other required fields as needed
      )

      # Create event for audit logging
      Event.create!(
        user: Current.user,
        action: 'evaluator_assigned',
        metadata: {
          application_id: id,
          evaluator_id: evaluator.id,
          evaluator_name: evaluator.full_name,
          timestamp: Time.current.iso8601
        }
      )

      # Send email notification to evaluator
      EvaluatorMailer.with(
        evaluation: evaluation,
        constituent: user
      ).new_evaluation_assigned.deliver_later
    end
    true
  rescue ::ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to assign evaluator: #{e.message}"
    false
  end

  def assign_trainer!(trainer)
    with_lock do
      training_session = training_sessions.create!(
        trainer: trainer,
        status: :requested
        # No default scheduled_for - this will be set by the trainer after coordinating with constituent
      )

      # Create event for audit logging
      Event.create!(
        user: Current.user,
        action: 'trainer_assigned',
        metadata: {
          application_id: id,
          trainer_id: trainer.id,
          trainer_name: trainer.full_name,
          timestamp: Time.current.iso8601
        }
      )

      # Create system notification for the constituent
      create_system_notification!(
        recipient: user,
        actor: Current.user,
        action: 'trainer_assigned'
      )

      # Send email notification to the trainer with constituent contact info
      TrainingSessionNotificationsMailer.trainer_assigned(training_session).deliver_later
    end
    true
  rescue ::ActiveRecord::RecordInvalid => e
    Rails.logger.error "Failed to assign trainer: #{e.message}"
    false
  end

  # Certification management
  def update_certification!(certification:, status:, verified_by:, rejection_reason: nil)
    with_lock do
      # Attach the certification if provided
      medical_certification.attach(certification) if certification.present?

      # Update the certification status and metadata
      attrs = {
        medical_certification_status: status,
        medical_certification_verified_at: Time.current,
        medical_certification_verified_by: verified_by
      }

      # Add rejection reason if provided
      attrs[:medical_certification_rejection_reason] = rejection_reason if status == 'rejected'

      update!(attrs)

      # Create notification for audit logging
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
    true
  rescue ::ActiveRecord::RecordInvalid => e
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
  rescue ::ActiveRecord::RecordInvalid => e
    Rails.logger.error "[Application #{id}] Failed to schedule training: #{e.message}"
    errors.add(:base, e.message)
    false
  end

  def latest_evaluation
    evaluations.order(created_at: :desc).first
  end

  def last_evaluation_completed_at
    evaluations.where(status: :completed).order(evaluation_date: :desc).limit(1).pluck(:evaluation_date).first
  end

  def all_evaluations
    evaluations.order(created_at: :desc)
  end

  def constituent_full_name
    # Checking if user exists and has both names to avoid nil errors
    return "#{user&.first_name} #{user&.last_name}".strip if user&.first_name || user&.last_name

    'Unknown Constituent'
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

  def medical_certification_requested?
    medical_certification_requested_at.present? ||
      medical_certification_status.in?(%w[requested received accepted rejected'])
  end

  private

  def log_status_change
    # Guard clause to prevent infinite recursion
    return if @logging_status_change

    # Use Current.user if available, otherwise use the application's user
    # This ensures the method works in both controller contexts and test environments
    acting_user = Current.user || user

    # Skip event creation if no user is available
    return unless acting_user

    # Set flag to prevent reentry
    @logging_status_change = true

    begin
      # Enhanced event with more detailed metadata
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
      # Don't raise the error, just log it
    ensure
      # Always reset the flag, even if an exception occurs
      @logging_status_change = false
    end
  end

  def schedule_admin_notifications
    # Only run in production or staging to avoid test failures
    return if Rails.env.test?

    # Skip if no needs_review_since or it didn't change
    return unless needs_review_since_changed? && needs_review_since.present?

    NotifyAdminsJob.perform_later(self)
  end

  def determine_evaluation_type
    user&.evaluations&.exists? ? :follow_up : :initial
  end

  def waiting_period_completed
    return unless user
    return if new_record?

    last_application = user&.applications&.where&.not(id: id)
                           &.order(application_date: :desc)&.first
    return unless last_application

    waiting_period = Policy.get('waiting_period_years') || 3
    return unless last_application.application_date > waiting_period.years.ago

    errors.add(:base, "You must wait #{waiting_period} years before submitting a new application.")
  end

  def needs_proof_review?
    saved_change_to_needs_review_since? && needs_review_since.present?
  end

  def notify_admins_of_new_proofs
    # Return early if user is nil
    return unless user

    # Fetch only the admin IDs, ensuring STI compatibility
    admin_ids = User.where(type: Admin.name).pluck(:id)

    # Return early if there are no admins
    return if admin_ids.empty?

    # Build the notifications array
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

    # Perform a bulk insert
    Notification.insert_all!(notifications)
  end

  def pending_proof_types
    types = []
    types << 'income' if income_proof_status_not_reviewed?
    types << 'residency' if residency_proof_status_not_reviewed?
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

  def constituent_must_have_disability
    return if user&.has_disability_selected?
    errors.add(:base, 'At least one disability must be selected before submitting an application.')
  end

  def validate_disability?
    # Only validate when transitioning from draft to a submitted state
    # or when already in a submitted state
    return false if status_draft?
    return true if saved_change_to_status? && status_before_last_save == 'draft'
    return true if submitted?

    false
  end

  def proof_status_consistency
    # Check if approved proofs have attachments
    if income_proof_status_approved? && !income_proof.attached?
      errors.add(:income_proof, 'must be attached when status is approved')
      Rails.logger.warn "Application #{id}: Income proof marked as approved but no file is attached"
    end

    return unless residency_proof_status_approved? && !residency_proof.attached?

    errors.add(:residency_proof, 'must be attached when status is approved')
    Rails.logger.warn "Application #{id}: Residency proof marked as approved but no file is attached"
  end

  def proof_attachment_integrity
    return if Thread.current[:paper_application_context]

    check_proof_integrity(income_proof, :income) if income_proof_status_not_reviewed?
    check_proof_integrity(residency_proof, :residency) if residency_proof_status_not_reviewed?
  end

  def check_proof_integrity(proof, proof_type)
    return unless proof&.attached?

    if proof&.blob&.created_at
      # Allow brand new attachments to remain :not_reviewed for up to 1 minute
      if proof.blob.created_at <= 1.minute.ago
        errors.add("#{proof_type}_proof_status".to_sym,
                   'cannot be not_reviewed when proof is attached')
        Rails.logger.warn "Application #{id}: #{proof_type.capitalize} proof is attached but status is not_reviewed"
      end
    else
      Rails.logger.warn "Application #{id}: #{proof_type.capitalize} proof blob missing created_at timestamp"
    end
  end
end
