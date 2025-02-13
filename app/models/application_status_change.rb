class ApplicationStatusChange < ApplicationRecord
  belongs_to :application
  belongs_to :user, optional: true

  validates :from_status, presence: true
  validates :to_status, presence: true
  validates :changed_at, presence: true

  before_validation :set_changed_at

  private

  def set_changed_at
    self.changed_at ||= Time.current
  end
end
