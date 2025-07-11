# frozen_string_literal: true

class ApplicationStatusChange < ApplicationRecord
  belongs_to :application
  belongs_to :user, optional: true

  enum :change_type, {
    medical_certification: 0,
    proof: 1,
    status: 2
  }

  validates :from_status, presence: true
  validates :to_status, presence: true
  validates :changed_at, presence: true

  before_validation :set_changed_at

  private

  def set_changed_at
    self.changed_at ||= Time.current
  end
end
