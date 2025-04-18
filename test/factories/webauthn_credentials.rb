# frozen_string_literal: true

FactoryBot.define do
  factory :webauthn_credential do
    external_id { SecureRandom.hex(16) }
    public_key { "test_public_key_#{SecureRandom.hex(8)}" }
    nickname { "Test Security Key #{SecureRandom.hex(4)}" }
    sign_count { 0 }
    user
  end
end
