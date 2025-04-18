class RecoveryRequest < ApplicationRecord
  belongs_to :user
  belongs_to :resolved_by, class_name: 'User', optional: true

  validates :status, presence: true
  validates :ip_address, presence: true
  validates :user_agent, presence: true

  # Default values
  after_initialize :set_default_values, if: :new_record?

  private

  def set_default_values
    self.status ||= 'pending'
  end
end
