class Application < ApplicationRecord
  include ApplicationStatusManagement
  include NotificationDelivery

  # Associations
  belongs_to :user, class_name: "Constituent", foreign_key: :user_id
  belongs_to :income_verified_by, class_name: "User", foreign_key: :income_verified_by_id, optional: true
  has_many :training_sessions, class_name: "TrainingSession"
  has_many :trainers, through: :training_sessions

  has_one :evaluation
  has_many :notifications, as: :notifiable, dependent: :destroy

  # Active Storage attachments
  has_one_attached :residency_proof
  has_one_attached :income_proof

  def status
    value = read_attribute(:status)
    return value if value.nil?  # Don't default to 0, just return nil if it's nil

    # Convert string to integer if needed
    value = self.class.statuses[value.to_sym] if value.is_a?(String)

    # Return the symbol key for the integer value
    self.class.statuses.key(value.to_i)
  end

  def status=(value)
    case value
    when Symbol
      write_attribute(:status, self.class.statuses[value])
    when String
      write_attribute(:status, self.class.statuses[value.to_sym])
    when Integer
      write_attribute(:status, value) if self.class.statuses.values.include?(value)
    end
  end

  # Enums for proof statuses
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

  # Helper methods for proof status checks
  def rejected_income_proof?
    income_proof_status_rejected?
  end

  def rejected_residency_proof?
    residency_proof_status_rejected?
  end

  # Validations
  validates :user, :application_date, :status, presence: true
  validate :waiting_period_completed, on: :create
  validate :correct_proof_mime_type
  validate :proof_size_within_limit

  # Conditional presence validations
  validates :residency_proof, :income_proof, presence: true, unless: :draft?
  validates :maryland_resident, inclusion: { in: [ true ], message: "You must be a Maryland resident to apply" }
  validates :terms_accepted, :information_verified, :medical_release_authorized, acceptance: { accept: true }, if: :submitted?
  validates :medical_provider_name, :medical_provider_phone, :medical_provider_email, presence: true, unless: :draft?
  validates :household_size, presence: true
  validates :annual_income, presence: true
  validates :self_certify_disability, inclusion: { in: [ true, false ] }
  validates :guardian_relationship, presence: true, if: :is_guardian?

  # Scopes
  scope :needs_review, -> { where(status: :needs_information) }
  scope :active, -> { where(status: [ :in_progress, :needs_information, :reminder_sent, :awaiting_documents ]) }
  scope :incomplete, -> { where(status: :in_progress) }
  scope :complete, -> { where(status: :approved) }
  scope :needs_evaluation, -> { where(status: :approved) }
  scope :needs_training, -> { where(status: :approved) }
  scope :submitted, -> { where.not(status: :draft) }
  scope :draft, -> { where(status: "draft") }

  # Updated Scopes to Match Enum Definitions
  scope :needs_income_review, -> { where(income_proof_status: :not_reviewed) }
  scope :needs_residency_review, -> { where(residency_proof_status: :not_reviewed) }
  scope :rejected_income_proofs, -> { where(income_proof_status: :rejected) }
  scope :rejected_residency_proofs, -> { where(residency_proof_status: :rejected) }

  # For proof review
  has_many :proof_reviews, dependent: :destroy
  after_update :schedule_admin_notifications, if: :needs_proof_review?

  def annual_income=(value)
    # Remove commas and convert to decimal
    cleaned_value = value.to_s.gsub(/,/, "").to_f
    super(cleaned_value)
  end

  def purge_proofs(admin_user)
    raise ArgumentError, "Admin user required" unless admin_user&.admin?

    ActiveRecord::Base.transaction do
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

  def valid?(*)
    result = super
    Rails.logger.debug "Validation result: #{result}"
    Rails.logger.debug "Validation errors: #{errors.full_messages}" unless result
    result
  end

  private

  def schedule_admin_notifications
    NotifyAdminsJob.perform_later(self)
  end

  def submitted?
    !draft?
  end

  def submit!
    update(status: :in_progress)  # Change from draft to in_progress status
  end

  def waiting_period_completed
    return unless user
    return if new_record? # Add this line - skip check for new applications

    Rails.logger.debug "Checking waiting period for user #{user.id}"
    last_application = user.applications.where.not(id: id).order(application_date: :desc).first

    Rails.logger.debug "Last application found: #{last_application.inspect}"
    return unless last_application

    waiting_period = Policy.get("waiting_period_years") || 3
    Rails.logger.debug "Waiting period: #{waiting_period} years"

    if last_application.application_date > waiting_period.years.ago
      Rails.logger.debug "Last application date: #{last_application.application_date}"
      Rails.logger.debug "Required wait until: #{waiting_period.years.ago}"
      errors.add(:base, "You must wait #{waiting_period} years before submitting a new application.")
    end
  end

  def correct_proof_mime_type
    allowed_types = [ "application/pdf", "image/jpeg", "image/png", "image/tiff", "image/bmp" ]

    if residency_proof.attached? && !allowed_types.include?(residency_proof.content_type)
      errors.add(:residency_proof, "must be a PDF or an image file (jpg, jpeg, png, tiff, bmp)")
    end

    if income_proof.attached? && !allowed_types.include?(income_proof.content_type)
      errors.add(:income_proof, "must be a PDF or an image file (jpg, jpeg, png, tiff, bmp)")
    end
  end

  def proof_size_within_limit
    max_size = 5.megabytes

    if residency_proof.attached? && residency_proof.byte_size > max_size
      errors.add(:residency_proof, "is too large. Maximum size allowed is 5MB.")
    end

    if income_proof.attached? && income_proof.byte_size > max_size
      errors.add(:income_proof, "is too large. Maximum size allowed is 5MB.")
    end
  end

  def needs_proof_review?
    saved_change_to_needs_review_since? && needs_review_since.present?
  end

  def notify_admins_of_new_proofs
    notifications = User.where(type: "Admin").map do |admin|
      {
        recipient: admin,
        actor: user,
        action: "proof_submitted",
        notifiable: self,
        metadata: { proof_types: pending_proof_types }
      }
    end
    Notification.insert_all!(notifications)
  end

  def pending_proof_types
    types = []
    types << "income" if income_proof_status_not_reviewed?
    types << "residency" if residency_proof_status_not_reviewed?
    types
  end

  def track_proof_purge
    ProofSubmissionAudit.create!(
      application: self,
      user: Current.user,
      action: "purged",
      metadata: { reason: "cleanup" }
    )
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
    # Assuming there's a boolean column or method in the User or Application model
    user&.is_guardian == true
  end
end
