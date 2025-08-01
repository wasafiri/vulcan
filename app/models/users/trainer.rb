# frozen_string_literal: true

module Users
  class Trainer < User
    has_many :training_sessions, dependent: :restrict_with_error
    has_many :assigned_constituents,
             through: :training_sessions,
             source: :constituent

    enum :status, { inactive: 0, active: 1, suspended: 2 }, default: :inactive, prefix: true

    scope :available, -> { where(status: :active) }
  end
end
