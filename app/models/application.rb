class Application < ApplicationRecord
  # Associations
  belongs_to :user, class_name: "Constituent", foreign_key: :user_id
  belongs_to :income_verified_by, class_name: "User", foreign_key: :income_verified_by_id, optional: true
  belongs_to :medical_provider, class_name: "MedicalProvider", foreign_key: :medical_provider_id, optional: true

  has_one :evaluation
  has_many :notifications, as: :notifiable, dependent: :destroy
  accepts_nested_attributes_for :medical_provider, allow_destroy: false, reject_if: :all_blank

  # Active Storage attachments
  has_one_attached :residency_proof
  has_one_attached :income_proof

  # Enums
  enum :status, {
    in_progress: 0,
    approved: 1,
    rejected: 2,
    needs_information: 3,
    reminder_sent: 4,
    awaiting_documents: 5
  }

  enum :application_type, {
    new_application: 0,
    renewal: 1
  }

  enum :submission_method, {
    online: 0,
    in_person: 1
  }

  enum :income_verification_status, {
    pending: 0,
    verified: 1,
    failed: 2
  }

  # Validations
  validates :user, :application_date, :status, presence: true
  validates :household_size, numericality: { greater_than: 0 }, allow_nil: true
  validates :annual_income, numericality: { greater_than: 0 }, allow_nil: true

  # Conditional presence validations
  validates :residency_proof, :income_proof, presence: true, unless: :draft?

  validates :maryland_resident, acceptance: { accept: true, message: "You must be a Maryland resident to apply" }
  validates :terms_accepted, :information_verified, :medical_release_authorized, acceptance: { accept: true }, if: :submitted?

  # Custom validations
  validate :waiting_period_completed, on: :create
  validate :correct_proof_mime_type
  validate :proof_size_within_limit

  # Scopes
  scope :pending_verification, -> { where(income_verification_status: :pending) }
  scope :needs_review, -> { where(status: :needs_information) }
  scope :active, -> { where(status: [ :in_progress, :needs_information, :reminder_sent, :awaiting_documents ]) }
  scope :incomplete, -> { where(status: :in_progress) }
  scope :complete, -> { where(status: :approved) }
  scope :needs_evaluation, -> { where(status: :approved) }
  scope :needs_training, -> { where(status: :approved) }

  # Callbacks
  before_validation :set_default_status, on: :create

  # Delegations for cleaner view access
  delegate :full_name, to: :medical_provider, prefix: true, allow_nil: true
  delegate :phone, :fax, :email, to: :medical_provider, prefix: true, allow_nil: true

  def medical_provider_name
    medical_provider&.full_name
  end

  def medical_provider_present?
    medical_provider.present?
  end

  private

  # Sets the default status to :in_progress if not already set
  def set_default_status
    self.status ||= :in_progress
  end

  # Determines if the application has been submitted (not a draft)
  def submitted?
    !draft
  end

  # Marks the application as submitted by setting draft to false
  def submit!
    update(draft: false)
  end

  # Validates that the user has completed the required waiting period before submitting a new application
  def waiting_period_completed
    return unless user

    last_application = user.applications.order(application_date: :desc).where.not(id: id).first
    if last_application
      waiting_period = Policy.get("waiting_period_years") || 3
      if last_application.application_date > waiting_period.years.ago
        errors.add(:base, "You must wait #{waiting_period} years before submitting a new application.")
      end
    end
  end

  # Validates that attached proofs have correct MIME types
  def correct_proof_mime_type
    allowed_types = [ "application/pdf", "image/jpeg", "image/png", "image/tiff", "image/bmp" ]

    if residency_proof.attached? && !allowed_types.include?(residency_proof.content_type)
      errors.add(:residency_proof, "must be a PDF or an image file (jpg, jpeg, png, tiff, bmp)")
    end

    if income_proof.attached? && !allowed_types.include?(income_proof.content_type)
      errors.add(:income_proof, "must be a PDF or an image file (jpg, jpeg, png, tiff, bmp)")
    end
  end

  # Validates that attached proofs do not exceed the size limit
  def proof_size_within_limit
    max_size = 5.megabytes

    if residency_proof.attached? && residency_proof.byte_size > max_size
      errors.add(:residency_proof, "is too large. Maximum size allowed is 5MB.")
    end

    if income_proof.attached? && income_proof.byte_size > max_size
      errors.add(:income_proof, "is too large. Maximum size allowed is 5MB.")
    end
  end
end
