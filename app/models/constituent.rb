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

  attribute :is_guardian, :boolean, default: false
  attribute :guardian_relationship, :string
  attribute :hearing_disability, :boolean, default: false
  attribute :vision_disability, :boolean, default: false
  attribute :speech_disability, :boolean, default: false
  attribute :mobility_disability, :boolean, default: false
  attribute :cognition_disability, :boolean, default: false

  # Add explicit setters to ensure proper type casting
  def is_guardian=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def guardian_relationship=(value)
    super(value)
  end

  def hearing_disability=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def vision_disability=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def speech_disability=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def mobility_disability=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  def cognition_disability=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end

  # Optional: Method to check inherited columns
  def self.inherited_columns
    column_names
  end

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
