class Event < ApplicationRecord
  belongs_to :user

  validates :action, presence: true
  validate :validate_metadata_structure

  before_create do
    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end

  private

  def validate_metadata_structure
    unless metadata.is_a?(Hash)
      errors.add(:metadata, "must be a JSON object")
    end
  end
end
