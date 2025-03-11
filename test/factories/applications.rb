FactoryBot.define do
  factory :application do
    # Required associations
    association :user, factory: [ :constituent, :with_disabilities ], strategy: :create

    # Base status fields with default values
    status { :in_progress }
    income_proof_status { :not_reviewed }  # Add default value
    residency_proof_status { :not_reviewed }  # Add default value

    # Other required fields
    application_date { Time.current }
    maryland_resident { true }
    self_certify_disability { true }
    medical_provider_name { generate(:medical_provider_name) }
    medical_provider_phone { generate(:medical_provider_phone) }
    medical_provider_fax { generate(:medical_provider_fax) }
    medical_provider_email { generate(:medical_provider_email) }
    household_size { 4 }
    annual_income  { 50_000 }

    after(:build) do |application|
      # Attach known good PDF files
      application.income_proof.attach(
        io: File.open(Rails.root.join('test/fixtures/files/income_proof.pdf')),
        filename: 'income_proof.pdf',
        content_type: 'application/pdf'
      )
      
      application.residency_proof.attach(
        io: File.open(Rails.root.join('test/fixtures/files/residency_proof.pdf')),
        filename: 'residency_proof.pdf',
        content_type: 'application/pdf'
      )
    end

    trait :completed do
      household_size { 4 }
      annual_income  { 50_000 }
      status { :approved }
      income_proof_status { :approved }
      residency_proof_status { :approved }
      terms_accepted { true }
      information_verified { true }
      medical_release_authorized { true }
      income_verified_at { Time.current }
      last_activity_at { Time.current }
      association :income_verified_by, factory: :admin
    end

    trait :rejected do
      household_size { 2 }
      annual_income  { 300_000 }
      status { :rejected }
      income_proof_status { :rejected }
      residency_proof_status { :rejected }
      terms_accepted { true }
      information_verified { true }
      medical_release_authorized { true }
      total_rejections { 1 }
      needs_review_since { Time.current }
      last_activity_at { Time.current }
    end

    trait :archived do
      household_size { 4 }
      annual_income  { 50_000 }
      status { :archived }
      income_proof_status { :approved }
      residency_proof_status { :approved }
      terms_accepted { true }
      information_verified { true }
      medical_release_authorized { true }
      application_date { 8.years.ago }
      last_activity_at { 8.years.ago }
    end

    trait :in_progress_with_rejected_proofs do
      household_size { 4 }
      annual_income  { 50_000 }
      status { :in_progress }
      income_proof_status { :rejected }
      residency_proof_status { :rejected }
      needs_review_since { Time.current }
      last_activity_at { Time.current }

      # Use the same PDF files as the base factory - the status is what matters
      # No need to override attachment behavior
    end

    trait :with_approved_proofs do
      income_proof_status { :approved }
      residency_proof_status { :approved }
      # Use the same PDF files as the base factory
    end

    trait :in_progress_with_approved_proofs do
      household_size { 4 }
      annual_income  { 50_000 }
      status { :in_progress }
      income_proof_status { :approved }
      residency_proof_status { :approved }
      last_activity_at { Time.current }
      # Use the same PDF files as the base factory
    end

    trait :in_progress_with_pending_proofs do
      household_size { 4 }
      annual_income  { 50_000 }
      status { :in_progress }
      income_proof_status { :not_reviewed }
      residency_proof_status { :not_reviewed }
      last_activity_at { Time.current }
      # Use the same PDF files as the base factory
    end

    trait :submitted_by_guardian do
      association :user, factory: [ :constituent, :as_guardian ], strategy: :create
    end

    trait :submitted_by_legal_guardian do
      association :user, factory: [ :constituent, :as_legal_guardian ], strategy: :create
    end
  end
end
