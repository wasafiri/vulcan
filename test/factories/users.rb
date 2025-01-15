# test/factories/users.rb
FactoryBot.define do
  unless FactoryBot.factories.registered?(:user)
    factory :user do
      email  # Uses the sequence defined in sequences.rb
      password { "password123" }
      first_name { "Test" }
      last_name { "User" }
      phone { "555-555-5555" }
      date_of_birth { 30.years.ago }
      timezone { "Eastern Time (US & Canada)" }
      locale { "en" }
      email_verified { true }
      verified { true }

      factory :admin, class: "Admin" do
        type { "Admin" }
        first_name { "Admin" }
      end

      factory :evaluator, class: "Evaluator" do
        type { "Evaluator" }
        first_name { "Test" }
        last_name { "Evaluator" }
        availability_schedule { { monday: [ "9:00", "17:00" ] } }
        status { :active }

        trait :inactive do
          status { :inactive }
        end

        trait :suspended do
          status { :suspended }
        end
      end

      factory :constituent, class: "Constituent" do
        type { "Constituent" }
        physical_address_1 { "123 Main St" }
        city { "Baltimore" }
        state { "MD" }
        zip_code { "21201" }

        trait :with_disabilities do
          hearing_disability { true }
          vision_disability { true }
          speech_disability { true }
        end

        trait :with_internet do
          home_internet_service { true }
        end
      end

      factory :vendor, class: "Vendor" do
        type { "Vendor" }
        status { :approved }

        trait :pending do
          status { :pending }
        end

        trait :suspended do
          status { :suspended }
        end
      end
    end
  end
end
