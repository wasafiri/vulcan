class Product < ApplicationRecord
  belongs_to :user, class_name: "Vendor"

  validates :name, presence: true
  validates :device_type, presence: true

  scope :available, -> { where("quantity > 0") }
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :by_device_type, ->(type) { where(device_type: type) }

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
