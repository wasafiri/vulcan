class Application < ApplicationRecord
  belongs_to :user, class_name: "Constituent", foreign_key: :user_id
  belongs_to :income_verified_by, class_name: "User", foreign_key: :income_verified_by_id, optional: true
  belongs_to :medical_provider, class_name: "MedicalProvider", optional: true

  has_many :evaluations
  has_many :notifications, as: :notifiable, dependent: :destroy

  validate :waiting_period_completed, on: :create

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

  # Scopes
  scope :pending_verification, -> { where(income_verification_status: :pending) }
  scope :needs_review, -> { where(status: :needs_information) }
  scope :active, -> { where(status: [ :in_progress, :needs_information, :reminder_sent, :in_progress, :awaiting_documents ]) }
  scope :incomplete, -> { where(status: :in_progress) }
  scope :complete, -> { where(status: :approved) }
  scope :needs_evaluation, -> { where(status: :approved) }
  scope :needs_training, -> { where(status: :approved) }

  # Callbacks
  before_validation :set_default_status, on: :create

  private

  def set_default_status
    self.status ||= :in_progress
  end

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
end
