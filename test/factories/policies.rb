# frozen_string_literal: true

FactoryBot.define do
  factory :policy do
    sequence(:key) { |n| "policy_key_#{n}" }
    value { 50 }

    # Traits for common policy types
    trait :rate_limit do
      sequence(:key) { |n| "proof_submission_rate_limit_web_#{n}" }
      value { 10 }
    end

    trait :voucher do
      sequence(:key) { |n| "voucher_value_hearing_disability_#{n}" }
      value { 500 }
    end
  end
end

# Helper method to clean up test policies - defined outside the factory
def cleanup_test_policies
  Policy.where("key LIKE 'policy_key_%' OR key LIKE '%_test_%'").delete_all
end
