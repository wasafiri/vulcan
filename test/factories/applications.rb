FactoryBot.define do
  factory :application do
    association :user, factory: :constituent
    association :medical_provider, factory: :medical_provider
    application_type { :new_application }
    submission_method { :online }
    status { :in_progress }
    application_date { 2.days.ago }
    household_size { 3 }
    annual_income { 45000 }
    income_verification_status { :pending }
    income_details { "Social Security Income and part-time employment" }
    residency_details { "Maryland resident for 15 years" }
    current_step { "income_verification" }
    received_at { 2.days.ago }
    last_activity_at { 1.day.ago }
    review_count { 0 }

    trait :in_prgress do
      status { :in_progress }
    end

    trait :approved do
      status { :approved }
      income_verification_status { :verified }
      income_verified_at { Time.current }
      current_step { "completed" }
      association :income_verified_by, factory: :admin
    end

    trait :needs_information do
      status { :needs_information }
      income_verification_status { :failed }
      income_details { "Need additional documentation" }
      residency_details { "Need proof of Maryland residency" }
      current_step { "documentation_required" }
    end
  end
end
