class RoleCapability < ApplicationRecord
  belongs_to :user

  # Define available capabilities
  CAPABILITIES = %w[can_train can_evaluate].freeze

  validates :capability, presence: true, inclusion: { in: CAPABILITIES }
  validates :user_id, uniqueness: { scope: :capability }
end
