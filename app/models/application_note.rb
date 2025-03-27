# frozen_string_literal: true

class ApplicationNote < ApplicationRecord
  belongs_to :application
  belongs_to :admin, class_name: 'User'

  validates :content, presence: true

  scope :recent_first, -> { order(created_at: :desc) }
  scope :public_notes, -> { where(internal_only: false) }
  scope :internal_notes, -> { where(internal_only: true) }
end
