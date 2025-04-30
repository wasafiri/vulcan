# frozen_string_literal: true

# Represents a constituent's application in the system
# Manages the application lifecycle including proof submission, review,
# medical certification, training sessions, evaluations, and voucher issuance
class Application < ApplicationRecord
  # Virtual attribute to hold nested medical provider params for the form
  attr_accessor :medical_provider_attributes

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
             optional: true,
             inverse_of: :income_verified_applications
  has_many :training_sessions, class_name: 'TrainingSession'
  has_many :trainers, through: :training_sessions
  has_many :evaluations, dependent: :destroy
  has_many :notifications, as: :notifiable, dependent: :destroy
  has_many :proof_reviews, dependent: :destroy
  has_many :status_changes, class_name: 'ApplicationStatusChange', dependent: :destroy
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
  enum :status, {
    draft: 0,               # Constituent still working on application
    in_progress: 1,         # Submitted by constituent, being processed
    approved: 2,            # Application approved
    rejected: 3,            # Application rejected
    needs_information: 4,   # Additional info needed from constituent
    reminder_sent: 5,       # Reminder sent to constituent
    awaiting_documents: 6,  # Waiting for specific documents
    archived: 7             # Historical record
  }, prefix: true, validate: true

  enum :income_proof_status, {
    not_reviewed: 0,
    approved: 1,
    rejected: 2
  }, prefix: true # Use standard boolean prefix

  enum :residency_proof_status, {
    not_reviewed: 0,
    approved: 1,
    rejected: 2
  }, prefix: true # Use standard boolean prefix

  enum :medical_certification_status, {
    not_requested: 0,
    requested: 1,
    received: 2,
    approved: 3,
    rejected: 4
  }, prefix: :medical_certification_status

  # Validations
  validates :user, :application_date, :status, presence: true
  validates :maryland_resident, inclusion: { in: [true], message: 'You must be a Maryland resident to apply' }, unless: :status_draft?
  validates :terms_accepted, :information_verified, :medical_release_authorized,
            acceptance: { accept: true }, if: :submitted?
  validates :medical_provider_name, :medical_provider_phone, :medical_provider_email,
            presence: true, unless: :status_draft?
  validates :household_size, :annual_income, presence: true, unless: :status_draft?
  validates :self_certify_disability, inclusion: { in: [true, false] }, unless: :status_draft?
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
  # Alias scope for approved applications
  scope :complete, lambda {
    where.not(status: :draft) # Application submitted
         .where(residency_proof_status: :approved)      # Residency approved
         .where(income_proof_status: :approved)         # Income approved
         .joins(:vouchers)                              # Must have at least one voucher issued
         .where(
           'NOT EXISTS (SELECT 1 FROM vouchers v WHERE v.application_id = applications.id AND v.status != ?)',
           Voucher.statuses[:redeemed]
         )
         .distinct # Avoid duplicates due to the join
  }

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
  # Delegates approval logic to the Applications::Approver service object
  # @param user [User] The user performing the action (defaults to Current.user)
  # @return [Boolean] Result from the service call
  def approve!(user: Current.user)
    Applications::Approver.new(self, by: user).call
  end

  # Delegates rejection logic to the Applications::Rejecter service object
  # @param user [User] The user performing the action (defaults to Current.user)
  # @return [Boolean] Result from the service call
  def reject!(user: Current.user)
    Applications::Rejecter.new(self, by: user).call
  end

  # Delegates document request logic to the Applications::DocumentRequester service object
  # @param user [User] The user performing the action (defaults to Current.user)
  # @return [Boolean] Result from the service call
  def request_documents!(user: Current.user)
    Applications::DocumentRequester.new(self, by: user).call
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
    latest_review, latest_audit = latest_review_and_audit(proof_type)

    # Case 1: No reviews yet, but has submission
    return true if latest_review.nil? && latest_audit.present?

    # Case 2: Has a new submission after the last review
    latest_audit.present? && latest_review.present? && latest_audit.created_at > latest_review.created_at
  end

  # Retrieves the latest review and audit for a given proof type
  # @param proof_type [String] The type of proof ("income" or "residency")
  # @return [Array] A two-element array containing the latest review and audit
  def latest_review_and_audit(proof_type)
    latest_review = proof_reviews.where(proof_type: proof_type).order(created_at: :desc).first
    latest_audit = proof_submission_audits.where(proof_type: proof_type).order(created_at: :desc).first

    [latest_review, latest_audit]
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

  # === Struct definitions ===
  # Definition for Medical Provider Info struct
  MedicalProviderInfo = Struct.new(:name, :phone, :fax, :email, keyword_init: true) do
    def present?
      name.present? || phone.present? || fax.present? || email.present?
    end

    def valid_phone?
      phone.present? && phone.match?(/\A[\d\-\(\)\s\.]+\z/)
    end

    def valid_email?
      email.present? && email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
    end
  end

  # Definition for ProofResult struct
  ProofResult = Struct.new(:success, :type, :message, :error, keyword_init: true) do
    def success?
      success == true
    end

    def error_message
      error&.message || message
    end
  end

  # Definition for ProofMetadata struct
  ProofMetadata = Struct.new(:blob_id, :content_type, :byte_size, :filename, keyword_init: true) do
    def to_h
      { blob_id: blob_id, content_type: content_type, byte_size: byte_size, filename: filename }
    end
  end

  # === Compatibility Methods ===
  # These methods ensure backward compatibility with code that expects
  # the previous enum method naming pattern with suffix

  # Income proof status compatibility methods
  def income_proof_status_approved_status?
    income_proof_status_approved?
  end

  def income_proof_status_rejected_status?
    income_proof_status_rejected?
  end

  def income_proof_status_not_reviewed_status?
    income_proof_status_not_reviewed?
  end

  # Residency proof status compatibility methods
  def residency_proof_status_approved_status?
    residency_proof_status_approved?
  end

  def residency_proof_status_rejected_status?
    residency_proof_status_rejected?
  end

  def residency_proof_status_not_reviewed_status?
    residency_proof_status_not_reviewed?
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
    return unless last_app.application_date > waiting_period.years.ago

    errors.add(:base, "You must wait #{waiting_period} years before submitting a new application.")
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
    # Get the value from the form submission if it's being processed
    if @attributes && @attributes['is_guardian'].present?
      # Use the form-submitted value
      ActiveModel::Type::Boolean.new.cast(@attributes['is_guardian'].value)
    elsif user&.changed? && user.changes.include?('is_guardian')
      # User has pending changes that aren't saved yet
      user.is_guardian_will_change
    else
      # Fall back to the current database value
      user&.is_guardian == true
    end
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
