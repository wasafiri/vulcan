# frozen_string_literal: true

# Manages the application lifecycle including proof submission, review,
# medical certification, training sessions, evaluations, and voucher issuance
class Application < ApplicationRecord
  # Alternate contact validations
  validates :alternate_contact_phone,
            format: { with: /\A\+?[\d\-\(\)\s]+\z/, allow_blank: true }
  validates :alternate_contact_email,
            format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
  # Virtual attribute to hold nested medical provider params for the form
  attr_accessor :medical_provider_attributes

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

  belongs_to :managing_guardian, # NEW ASSOCIATION
             class_name: 'User',
             optional: true,
             inverse_of: :managed_applications # User model will need has_many :managed_applications

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
  validates :application_date, :status, presence: true
  validates :maryland_resident, inclusion: { in: [true], message: 'You must be a Maryland resident to apply' }, unless: :status_draft?
  validates :terms_accepted, :information_verified, :medical_release_authorized,
            acceptance: { accept: true }, if: :submitted?
  validates :medical_provider_name, :medical_provider_phone, :medical_provider_email,
            presence: true, unless: :status_draft?
  validates :household_size, :annual_income, presence: true, unless: :status_draft?
  validates :self_certify_disability, inclusion: { in: [true, false] }, unless: :status_draft?
  # REMOVED VALIDATION: validates :guardian_relationship, presence: true, if: :is_guardian?
  # The old :is_guardian? method on Application is also being replaced/repurposed.

  validate :waiting_period_completed, on: :create
  validate :constituent_must_have_disability, if: :validate_disability?

  after_create :ensure_managing_guardian_set
  # Callbacks
  after_update :log_status_change, if: :saved_change_to_status?
  after_save :ensure_managing_guardian_set, if: :user_id_previously_changed?
  after_save :log_alternate_contact_changes, if: :saved_change_to_alternate_contact?

  # Scopes
  scope :draft, -> { where(status: :draft) }
  scope :search_by_last_name, lambda { |query|
    includes(:user, :proof_reviews, :training_sessions, :evaluations)
      .where('users.last_name ILIKE ?', "%#{query}%")
      .references(:users)
  }

  # Guardian/Dependent relationship scopes
  scope :managed_by, lambda { |guardian_user|
    where(managing_guardian_id: guardian_user.id)
  }

  scope :for_dependents_of, lambda { |guardian_user|
    if guardian_user
      joins('INNER JOIN guardian_relationships ON applications.user_id = guardian_relationships.dependent_id')
        .where(guardian_relationships: { guardian_id: guardian_user.id })
    else
      none
    end
  }

  # Returns all applications related to a guardian, either managed by them
  # or for one of their dependents (even if not managed by this guardian)
  scope :related_to_guardian, lambda { |guardian_user|
    managed_by(guardian_user)
      .or(for_dependents_of(guardian_user))
  }

  # Alias scopes for approved applications
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

  scope :with_pending_training, lambda {
    joins(:training_sessions).merge(TrainingSession.where(status: %i[requested scheduled confirmed])).distinct
  }

  scope :with_active_training_for_trainer, lambda { |trainer_id|
    joins(:training_sessions).where(
      training_sessions: {
        trainer_id: trainer_id,
        status: %i[scheduled confirmed]
      }
    ).distinct
  }

  # Class Methods for Analysis
  def self.pain_point_analysis
    draft
      .where.not(last_visited_step: [nil, ''])
      .group(:last_visited_step)
      .order('count_all DESC')
      .count
  end

  # Status methods- Delegate approval logic to the Applications::Approver service object
  def approve!(user: Current.user)
    Applications::Approver.new(self, by: user).call
  end

  # Delegate rejection logic to the Applications::Rejecter service object
  def reject!(user: Current.user)
    Applications::Rejecter.new(self, by: user).call
  end

  # Delegate document request logic to the Applications::DocumentRequester service object
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

  # New method to check if the application is for a dependent (managed by a guardian)
  def for_dependent?
    managing_guardian_id.present?
  end

  # Returns the guardian relationship type for this application
  def guardian_relationship_type
    return nil unless for_dependent?

    # Look up the relationship type from the GuardianRelationship table
    GuardianRelationship.find_by(
      guardian_id: managing_guardian_id,
      dependent_id: user_id
    )&.relationship_type
  end

  # Add a condition method to check if any alternate contact field changed
  def saved_change_to_alternate_contact?
    saved_change_to_alternate_contact_name? ||
      saved_change_to_alternate_contact_phone? ||
      saved_change_to_alternate_contact_email?
  end

  # Log changes to alternate contact fields
  def log_alternate_contact_changes
    changed_attributes = {}
    %w[name phone email].each do |field|
      attribute = "alternate_contact_#{field}"
      if saved_change_to_attribute?(attribute)
        old_value, new_value = saved_change_to_attribute(attribute)
        changed_attributes[attribute] = { old: old_value, new: new_value }
      end
    end

    # Only log if there were actual changes to alternate contact fields
    return unless changed_attributes.present?

    # Use Event model to log the changes
    Event.create!(
      user: Current.user || user, # Use Current.user if available, otherwise fall back to the application's user
      action: 'alternate_contact_updated',
      metadata: {
        application_id: id,
        changes: changed_attributes,
        changed_by: Current.user&.id,
        timestamp: Time.current.iso8601
      }
    )
  rescue StandardError => e
    Rails.logger.error "Failed to log alternate contact changes for application #{id}: #{e.message}"
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

  # Method replaced by for_dependent?

  def constituent_must_have_disability
    return if user&.disability_selected?

    errors.add(:base, 'At least one disability must be selected before submitting an application.')
  end

  def validate_disability?
    return false if status_draft?
    return true if saved_change_to_status? && status_before_last_save == 'draft'
    return true if submitted?

    false
  end

  # Ensures the managing_guardian_id is set when the application is for a dependent
  # This is called after create and when user_id changes
  def ensure_managing_guardian_set
    # Skip if the application already has a managing guardian
    return if managing_guardian_id.present?

    # Skip if there's no user set yet
    return if user_id.blank?

    # Find if there's any guardian relationship for this user (dependent)
    guardian_relationship = GuardianRelationship.where(dependent_id: user_id).first

    # If there is a guardian relationship, set the managing_guardian_id to the guardian_id
    return unless guardian_relationship.present?

    Rails.logger.info "Setting managing_guardian_id to #{guardian_relationship.guardian_id} for application #{id}"

    # Use update_column to avoid callbacks and validations
    update_column(:managing_guardian_id, guardian_relationship.guardian_id)
  end
end
