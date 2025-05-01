# frozen_string_literal: true

# test/factories/sequences.rb
FactoryBot.define do
  unless FactoryBot.factories.registered?(:email)
    # Define sequences without conditionals
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:medical_provider_name) { |n| "Dr. Jane Smith #{n}" }
    sequence(:medical_provider_phone) { |n| "123-456-#{n.to_s.rjust(4, '0')}" }
    sequence(:medical_provider_fax) { |n| "098-765-#{n.to_s.rjust(4, '0')}" }
    sequence(:medical_provider_email) { |n| "jane.smith#{n}@medicalclinic.com" }
    sequence(:phone) { |n| "555-#{n.to_s.rjust(3, '0')}-#{n.to_s.rjust(4, '0')}" } # Generates 555-001-0001, 555-002-0002, etc.
  end
end
