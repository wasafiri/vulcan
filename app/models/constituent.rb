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

  DISABILITY_TYPES = %w[hearing vision speech mobility cognition].freeze

  # Define boolean attributes with defaults
  attribute :is_guardian, :boolean, default: false
  attribute :guardian_relationship, :string
  
  DISABILITY_TYPES.each do |type|
    attribute :"#{type}_disability", :boolean, default: false
  end

  # Validations for disability fields
  validates :guardian_relationship, presence: true, if: :is_guardian
  
  # Cast boolean values properly
  def is_guardian=(value)
    super(ActiveModel::Type::Boolean.new.cast(value))
  end
  
  DISABILITY_TYPES.each do |type|
    define_method("#{type}_disability=") do |value|
      super(ActiveModel::Type::Boolean.new.cast(value))
    end
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
