# frozen_string_literal: true

FactoryBot.define do
  unless FactoryBot.factories.registered?(:appointment)
    factory :appointment do
      user { nil }
      evaluator { nil }
      appointment_type { 1 }
      scheduled_for { '2024-12-23 21:25:36' }
      completed_at { '2024-12-23 21:25:36' }
      notes { 'MyText' }
    end
  end
end
