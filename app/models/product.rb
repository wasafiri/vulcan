class Product < ApplicationRecord
  has_and_belongs_to_many :evaluations
  has_and_belongs_to_many :vendors,
    class_name: "User",
    join_table: "products_users"

  validates :name, :manufacturer, :model_number, :device_type, presence: true
  validates :documentation_url, format: { with: URI::DEFAULT_PARSER.make_regexp }, allow_blank: true

  validates :device_types, presence: true

  DEVICE_TYPES = [
    "Smartphone",
    "Tablet",
    "Wearable Device",
    "Captioned Phone",
    "Amplified Phone",
    "Signaler",
    "Speech Device",
    "Smart Home Device",
    "Cellular 911 Alerter",
    "Switch Activated Device",
    "Eye-Tracking System",
    "Hands-free Device",
    "Memory Aid Device",
    "Braille Device"
  ].freeze

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :by_device_type, ->(type) { where(device_type: type) }
  scope :by_manufacturer, ->(manufacturer) { where(manufacturer: manufacturer) }

  def archive!
    update(archived_at: Time.current)
  end

  def unarchive!
    update(archived_at: nil)
  end

  def archived?
    archived_at.present?
  end
end
