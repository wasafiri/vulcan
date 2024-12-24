class Policy < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :value, presence: true, numericality: { only_integer: true }

  # Helper method to retrieve policy value by key
  def self.get(key)
    find_by(key: key)&.value
  end

  # Helper method to set or update a policy
  def self.set(key, value)
    policy = find_or_initialize_by(key: key)
    policy.value = value
    policy.save!
  end
end
