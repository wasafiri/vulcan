# frozen_string_literal: true

class WebauthnCredential < ApplicationRecord
  belongs_to :user

  encrypts :public_key

  validates :external_id, presence: true, uniqueness: true
  validates :public_key, presence: true
  validates :nickname, presence: true
  validates :sign_count, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
