# frozen_string_literal: true

class Trainer < User
  has_many :training_sessions, foreign_key: :trainer_id
  has_many :applications, through: :training_sessions

  enum :status, { inactive: 0, active: 1, suspended: 2 }, default: :inactive, prefix: true
  scope :available, -> { where(status: :active) }
  scope :active, -> { where(status: :active) }

  validates :availability_schedule, presence: true
end
