# frozen_string_literal: true

FactoryBot.define do
  unless FactoryBot.factories.registered?(:user)
    factory :user do
      sequence(:email) { |n| "user#{n}@example.com" }
      password { 'password123' }
      first_name { 'Test' }
      last_name { 'User' }
      phone # Use the sequence defined in sequences.rb
      date_of_birth { 30.years.ago }
      timezone { 'Eastern Time (US & Canada)' }
      locale { 'en' }
      email_verified { true }
      verified { true }

      factory :admin, class: 'Users::Administrator' do
        sequence(:email) { |n| "admin#{n}@example.com" }
        type { 'Administrator' }
        first_name { 'Admin' }
      end

      factory :evaluator, class: 'Users::Evaluator' do
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
        sequence(:email) { |n| "trainer#{n}@example.com" }
        type { 'Users::Trainer' }
        first_name { 'Test' }
        last_name { 'Trainer' }
      end

      factory :constituent, class: 'Users::Constituent' do # Match class name used in controller/associations
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

        trait :with_address_and_phone do
          physical_address_1 { '456 Oak Ave' }
          physical_address_2 { 'Apt 101' }
          city { 'Silver Spring' }
          state { 'MD' }
          zip_code { '20901' }
          phone { '111-222-3333' }
        end
      end
    end
  end

  factory :vendor_user, parent: :user, class: 'Users::Vendor' do
    type { 'Users::Vendor' }
    business_name { "Vendor Business #{rand(1000)}" }
    phone { "555-#{rand(100..999)}-#{rand(1000..9999)}" }
    business_tax_id { "ABC-#{rand(1000..9999)}" } # Add a default business_tax_id
    # other vendor-specific attributes
  end
end
