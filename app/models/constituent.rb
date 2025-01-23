class Constituent < User
  # Associations
  has_many :applications, foreign_key: :user_id, dependent: :destroy
  has_many :appointments, foreign_key: :user_id
  has_many :evaluations, foreign_key: :constituent_id
  has_many :assigned_evaluators, through: :evaluations, source: :evaluator
  validate :must_have_at_least_one_disability

  # Scopes
  scope :needs_evaluation, -> { joins(:application).where(applications: { status: :approved }) }
  scope :active, -> { where.not(status: [ :withdrawn, :rejected, :expired ]) }
  scope :ytd, -> {
    where("created_at >= ?", Date.new(Date.current.year >= 7 ? Date.current.year : Date.current.year - 1, 7, 1))
  }

  def active_application?
    active_application.present?
  end

  def active_application
    applications.active.order(application_date: :desc).first
  end

  private

  def must_have_at_least_one_disability
    unless hearing_disability || vision_disability || speech_disability || mobility_disability || cognition_disability
      errors.add(:base, "At least one disability must be selected.")
    end
  end
end
