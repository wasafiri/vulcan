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
    sequence(:phone) { |_n| "555-#{rand(100..999)}-#{rand(1000..9999)}" } # Generates valid 10-digit phone numbers like 555-XXX-XXXX
  end
end
