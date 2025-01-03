# app/models/policy.rb
class Policy < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true, numericality: { only_integer: true }

  has_many :policy_changes

  after_update :log_change

  private

  def log_change
    if saved_change_to_value?
      policy_changes.create!(
        user: Current.user,
        previous_value: value_before_last_save,
        new_value: value
      )
    end
  end
end
