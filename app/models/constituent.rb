# app/models/constituent.rb
class Constituent < User
  # Associations
  has_many :applications, foreign_key: :user_id, dependent: :destroy
  has_many :appointments, foreign_key: :user_id
  has_many :evaluations, foreign_key: :constituent_id
  has_many :assigned_evaluators, through: :evaluations, source: :evaluator

  # Validations
  validates :income_proof, :residency_proof, presence: true

  # Scopes
  scope :needs_evaluation, -> { joins(:application).where(applications: { status: :approved }) }
  scope :active, -> { where.not(status: [ :withdrawn, :rejected, :expired ]) }

  def active_application?
    active_application.present?
  end

  def active_application
    applications.active.order(application_date: :desc).first
  end
end
