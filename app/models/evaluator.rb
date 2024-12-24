class Evaluator < User
  has_many :appointments, foreign_key: :evaluator_id
  has_many :evaluations, foreign_key: :evaluator_id
  has_many :assigned_constituents, through: :evaluations, source: :constituent

  validates :availability_schedule, presence: true

  enum :status, { inactive: 0, active: 1, suspended: 2 }, default: :inactive

  scope :available, -> { where(status: :active) }
end
