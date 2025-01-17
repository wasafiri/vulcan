class RoleCapability < ApplicationRecord
  belongs_to :user

  # Define available capabilities
  CAPABILITIES = %w[can_train can_evaluate].freeze

  validates :capability, presence: true, inclusion: { in: CAPABILITIES }
  validates :user_id, uniqueness: { scope: :capability }
  validate :capability_valid_for_role

  private

  def capability_valid_for_role
    if user.present? && redundant_capability?
      errors.add(:capability, "is already included in user's primary role")
    end
  end

  def redundant_capability?
    case capability
    when "can_evaluate"
      if user.admin? || user.evaluator?
    when "can_train"
      if user.admin? || user.trainer?
    else
      false
    end
  end
end
