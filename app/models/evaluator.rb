class Evaluator < User
  has_many :appointments, foreign_key: :evaluator_id
  has_many :evaluations, foreign_key: :evaluator_id, dependent: :restrict_with_error
  has_many :assigned_constituents,
    through: :evaluations,
    source: :constituent

  enum :status, { inactive: 0, active: 1, suspended: 2 }, default: :inactive, prefix: true

  scope :available, -> { where(status: :active) }
end
