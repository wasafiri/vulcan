# frozen_string_literal: true

FactoryBot.define do
  unless FactoryBot.factories.registered?(:policy)
    factory :policy do
      sequence(:key) { |n| "policy_key_#{n}" }
      value { 3 }

      trait :max_training_sessions do
        key { 'max_training_sessions' }
        value { 3 }
      end

      trait :waiting_period_years do
        key { 'waiting_period_years' }
        value { 3 }
      end

      trait :proof_submission_rate_limit_web do
        key { 'proof_submission_rate_limit_web' }
        value { 5 }
      end

      trait :proof_submission_rate_limit_email do
        key { 'proof_submission_rate_limit_email' }
        value { 5 }
      end

      trait :proof_submission_rate_period do
        key { 'proof_submission_rate_period' }
        value { 24 }
      end

      trait :max_proof_rejections do
        key { 'max_proof_rejections' }
        value { 3 }
      end
    end
  end
end
