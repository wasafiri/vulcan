class PolicyChange < ApplicationRecord
  belongs_to :policy
  belongs_to :user

  validates :previous_value, presence: true
  validates :new_value, presence: true
end
