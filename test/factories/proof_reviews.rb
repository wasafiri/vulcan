FactoryBot.define do
  factory :proof_review do
    association :application
    association :admin
    proof_type { :income }  # or :residency
    status { :approved }
    reviewed_at { Time.current }

    trait :approved do
      status { :approved }
    end

    trait :rejected do
      status { :rejected }
      rejection_reason { "Invalid documentation" }
    end
  end
end
