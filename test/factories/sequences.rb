# frozen_string_literal: true

# test/factories/sequences.rb
FactoryBot.define do
  unless FactoryBot.factories.registered?(:email)
    # Define sequences without conditionals
    sequence(:email) { |n| "user#{n}@factory.com" } # Use a different domain for factory emails
    sequence(:medical_provider_name) { |n| "Dr. Jane Smith #{n}" }
    sequence(:medical_provider_phone) { |n| "123-456-#{n.to_s.rjust(4, '0')}" }
    sequence(:medical_provider_fax) { |n| "098-765-#{n.to_s.rjust(4, '0')}" }
    sequence(:medical_provider_email) { |n| "jane.smith#{n}@medicalclinic.com" }
    sequence(:phone) { |n| "555-#{(n % 900) + 100}-#{(n % 9000) + 1000}" } # Ensures unique 10-digit phone numbers by using sequence number
  end
end
