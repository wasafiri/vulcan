# app/models/policy.rb
class Policy < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true, numericality: { only_integer: true }
  has_many :policy_changes
  attr_accessor :updated_by
  after_update :log_change

  def self.get(key)
    find_by(key: key)&.value
  end

  def self.set(key, value)
    policy = find_or_initialize_by(key: key)
    policy.value = value
    policy.save!
  end

  private

  def log_change
    if saved_change_to_value?
      policy_changes.create!(
        user: updated_by,  # Changed from Current.user to updated_by
        previous_value: value_before_last_save,
        new_value: value
      )
    end
  end
end
