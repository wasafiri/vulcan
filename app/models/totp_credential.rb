# frozen_string_literal: true

class TotpCredential < ApplicationRecord
  belongs_to :user

  encrypts :secret

  validates :secret, presence: true
  validates :nickname, presence: true
  validates :last_used_at, presence: true

  before_validation :set_last_used_at, on: :create

  private

  def set_last_used_at
    self.last_used_at ||= Time.current
  end
end
