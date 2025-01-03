FactoryBot.define do
  factory :policy do
    sequence(:key) { |n| "policy_key_#{n}" }
    value { 3 }

    trait :max_training_sessions do
      key { "max_training_sessions" }
      value { 3 }
    end

    trait :waiting_period_years do
      key { "waiting_period_years" }
      value { 3 }
    end
  end
end
