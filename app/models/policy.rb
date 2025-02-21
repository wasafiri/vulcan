class Policy < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true, numericality: { only_integer: true }
  validates :value, numericality: {
    greater_than: 0,
    less_than_or_equal_to: 100
  }, if: -> { RATE_LIMIT_KEYS.include?(key) }

  has_many :policy_changes
  attr_accessor :updated_by
  after_update :log_change

  RATE_LIMIT_KEYS = %w[
    proof_submission_rate_limit_web
    proof_submission_rate_limit_email
    proof_submission_rate_period
  ].freeze

  def self.rate_limit_for(action, method)
    {
      max: get("#{action}_rate_limit_#{method}"),
      period: get("#{action}_rate_period").hours
    }
  end

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
