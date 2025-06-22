# frozen_string_literal: true

FactoryBot.define do
  factory :role_capability do
    user
    capability { 'can_train' }
  end
end
