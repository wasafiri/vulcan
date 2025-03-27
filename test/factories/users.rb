# frozen_string_literal: true

FactoryBot.define do
  unless FactoryBot.factories.registered?(:user)
    factory :user do
      sequence(:email) { |n| "user#{n}@example.com" }
      password { 'password123' }
      first_name { 'Test' }
      last_name { 'User' }
      phone { '555-555-5555' }
      date_of_birth { 30.years.ago }
      timezone { 'Eastern Time (US & Canada)' }
      locale { 'en' }
      email_verified { true }
      verified { true }

      factory :admin, class: 'Admin' do
        sequence(:email) { |n| "admin#{n}@example.com" }
        type { 'Admin' }
        first_name { 'Admin' }
      end

      factory :evaluator, class: 'Evaluator' do
        type { 'Evaluator' }
        first_name { 'Test' }
        last_name { 'Evaluator' }
        availability_schedule { { monday: ['9:00', '17:00'] } }
        status { :evaluator_active }

        trait :inactive do
          status { :evaluator_inactive }
        end

        trait :suspended do
          status { :evaluator_suspended }
        end
      end

      factory :constituent, class: 'Constituent' do
        type { 'Constituent' }
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

        trait :as_guardian do
          is_guardian { true }
          guardian_relationship { 'Parent' }
        end

        trait :as_legal_guardian do
          is_guardian { true }
          guardian_relationship { 'Legal Guardian' }
        end

        trait :with_internet do
          home_internet_service { true }
        end

        trait :with_active_application do
          after(:create) do |constituent|
            create(:application, user: constituent)
          end
        end
      end
    end
  end
end
