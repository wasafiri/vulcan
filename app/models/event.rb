# frozen_string_literal: true

class Event < ApplicationRecord
  belongs_to :user

  validates :action, presence: true
  validate :validate_metadata_structure

  before_create do
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end

  # Ensure metadata is always a hash
  def metadata
    super || {}
  end

  # Scope for finding events by metadata key/value
  scope :with_metadata, lambda { |key, value|
    where('metadata @> ?', { key => value }.to_json)
  }

  private

  def validate_metadata_structure
    return if metadata.is_a?(Hash)

    errors.add(:metadata, 'must be a JSON object')
  end
end
