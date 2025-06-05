# frozen_string_literal: true

FactoryBot.define do
  unless FactoryBot.factories.registered?(:user)
    factory :user do
      sequence(:email) { |n| "user#{n}@example.com" }
      password { 'password123' }
      first_name { 'Test' }
      last_name { 'User' }
      sequence(:phone) { |n| "555-#{format('%03d', (n % 900) + 100)}-#{format('%04d', (n % 9000) + 1000)}" }
      phone_type { 'voice' } # Default phone type
      date_of_birth { 30.years.ago }
      timezone { 'Eastern Time (US & Canada)' }
      locale { 'en' }
      email_verified { true }
      verified { true }

      factory :admin, class: 'Users::Administrator' do
        sequence(:email) { |n| "admin#{n}@example.com" }
        type { 'Users::Administrator' } # Ensure STI type matches class name
        first_name { 'Admin' }
        # Ensure admin users are verified for login
        email_verified { true }
        verified { true }
      end

      factory :evaluator, class: 'Users::Evaluator' do
        sequence(:email) { |n| "evaluator#{n}@example.com" }
        type { 'Users::Evaluator' }
        first_name { 'Test' }
        last_name { 'Evaluator' }
        availability_schedule { { monday: ['9:00', '17:00'] } }
        status { :active }

        trait :inactive do
          status { :inactive }
        end

        trait :suspended do
          status { :suspended }
        end
      end

      factory :trainer, class: 'Users::Trainer' do
        # Add SecureRandom to ensure uniqueness across test runs, avoiding potential sequence reset issues or fixture conflicts
        sequence(:email) { |n| "trainer_#{n}_#{SecureRandom.hex(4)}@example.com" }
        type { 'Users::Trainer' }
        first_name { 'Test' }
        last_name { 'Trainer' }
      end

      factory :constituent, class: 'Users::Constituent' do # Match class name used in controller/associations
        first_name { 'Test' }
        last_name { 'Constituent' }
        sequence(:email) { |n| "constituent#{n}@example.com" }
        type { 'Users::Constituent' } # Set type explicitly to match controller expectation
        physical_address_1 { '123 Main St' }
        city { 'Baltimore' }
        state { 'MD' }
        zip_code { '21201' }

        # Set default disability to pass validation
        after(:build) do |constituent|
          unless constituent.hearing_disability ||
                 constituent.vision_disability ||
                 constituent.speech_disability ||
                 constituent.mobility_disability ||
                 constituent.cognition_disability
            constituent.hearing_disability = true
          end
        end

        trait :with_disabilities do
          hearing_disability { true }
          vision_disability { true }
          speech_disability { true }
          mobility_disability { true }
          cognition_disability { true }
        end

        # DEPRECATED: Use :with_dependent trait instead or create GuardianRelationship directly.
        # This trait now creates a single dependent for the guardian.
        trait :as_guardian do
          transient do
            dependent_user { create(:constituent, first_name: 'Dependent', last_name: 'Child') }
          end
          after(:create) do |guardian, evaluator|
            create(:guardian_relationship, guardian_user: guardian, dependent_user: evaluator.dependent_user, relationship_type: 'Parent')
          end
        end

        # DEPRECATED: Use :with_dependent trait with specific relationship_type.
        # This trait now creates a single dependent with 'Legal Guardian' relationship.
        trait :as_legal_guardian do
          transient do
            dependent_user { create(:constituent, first_name: 'Dependent', last_name: 'Ward') }
          end
          after(:create) do |guardian, evaluator|
            create(:guardian_relationship, guardian_user: guardian, dependent_user: evaluator.dependent_user,
                                           relationship_type: 'Legal Guardian')
          end
        end

        trait :with_dependent do
          transient do
            dependent_relationship_type { 'Parent' }
            dependent_attributes { { first_name: 'Dependent', last_name: 'Child' } }
          end
          after(:create) do |guardian, evaluator|
            dependent = create(:constituent, evaluator.dependent_attributes)
            create(:guardian_relationship, guardian_user: guardian, dependent_user: dependent,
                                           relationship_type: evaluator.dependent_relationship_type)
          end
        end

        trait :with_dependents do
          transient do
            dependents_count { 1 }
            dependent_relationship_type { 'Parent' }
          end
          after(:create) do |guardian, evaluator|
            evaluator.dependents_count.times do |i|
              dependent = create(:constituent, first_name: "Dependent#{i + 1}", last_name: guardian.last_name)
              create(:guardian_relationship, guardian_user: guardian, dependent_user: dependent,
                                             relationship_type: evaluator.dependent_relationship_type)
            end
          end
        end

        trait :with_guardian do
          transient do
            guardian_user { create(:constituent, first_name: 'Guardian', last_name: 'Parent') }
            guardian_relationship_type { 'Parent' }
          end
          after(:create) do |dependent, evaluator|
            create(:guardian_relationship, guardian_user: evaluator.guardian_user, dependent_user: dependent,
                                           relationship_type: evaluator.guardian_relationship_type)
          end
        end

        trait :with_internet do
          home_internet_service { true }
        end

        trait :with_active_application do
          after(:create) do |constituent|
            create(:application, user: constituent) # This might need adjustment if dependent has guardian
          end
        end

        trait :with_address_and_phone do
          physical_address_1 { '456 Oak Ave' }
          physical_address_2 { 'Apt 101' }
          city { 'Silver Spring' }
          state { 'MD' }
          zip_code { '20901' }
          phone { '111-222-3333' }
          phone_type { 'voice' }
        end

        # Phone type traits
        trait :voice_phone do
          phone_type { 'voice' }
        end

        trait :videophone do
          phone_type { 'videophone' }
        end

        trait :text_phone do
          phone_type { 'text' }
        end

        trait :with_voice_phone do
          phone { '301-555-0001' }
          phone_type { 'voice' }
        end

        trait :with_videophone do
          phone { '301-555-0002' }
          phone_type { 'videophone' }
        end

        trait :with_text_phone do
          phone { '301-555-0003' }
          phone_type { 'text' }
        end

        # Trait for a user who is a guardian
        # In the paper application context, guardians are created as Constituents.
        # This trait is primarily to satisfy the `create(:user, :guardian)` call.
        trait :guardian do
          # Add any specific guardian attributes here if needed in the future.
          # For now, being a constituent is sufficient for the search.
          first_name { 'Guardian' }
          sequence(:last_name) { |n| "Test#{n}" }
        end
      end
    end
  end

  factory :vendor_user, parent: :user, class: 'Users::Vendor' do
    sequence(:email) { |n| "vendor#{n}@example.com" }
    type { 'Users::Vendor' }
    business_name { "Vendor Business #{rand(1000)}" }
    phone { "555-#{rand(100..999)}-#{rand(1000..9999)}" }
    phone_type { 'voice' }
    business_tax_id { "ABCDEF#{rand(100_000..999_999)}" }
    terms_accepted_at { Time.current }
    status { :approved } # Default to an approved vendor
    w9_status { :approved } # Default to W9 approved

    after(:build) do |vendor|
      unless vendor.w9_form.attached?
        vendor.w9_form.attach(
          io: File.open(Rails.root.join('test/fixtures/files/sample_w9.pdf')),
          filename: 'sample_w9.pdf',
          content_type: 'application/pdf'
        )
      end
    end

    trait :pending_approval do
      status { :pending }
      w9_status { :pending_review }
    end

    trait :not_yet_submitted_w9 do
      status { :pending }
      w9_status { :not_submitted }
      after(:build) do |vendor|
        vendor.w9_form.detach if vendor.w9_form.attached?
      end
    end
  end
end
