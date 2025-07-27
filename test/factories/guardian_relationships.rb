# frozen_string_literal: true

FactoryBot.define do
  factory :guardian_relationship do
    guardian_user factory: %i[constituent] # Use constituent factory for more realistic data
    dependent_user factory: %i[constituent] # Use constituent factory for more realistic data
    relationship_type { 'Parent' }

    # Trait for a specific relationship type
    trait :legal_guardian do
      relationship_type { 'Legal Guardian' }
    end

    trait :caretaker do
      relationship_type { 'Caretaker' }
    end

    # Traits for different phone types on dependent
    trait :dependent_with_voice_phone do
      dependent_user { association(:constituent, :with_voice_phone) }
    end

    trait :dependent_with_videophone do
      dependent_user { association(:constituent, :with_videophone) }
    end

    trait :dependent_with_text_phone do
      dependent_user { association(:constituent, :with_text_phone) }
    end

    # Trait for dependent sharing guardian's contact info
    trait :dependent_shares_contact do
      after(:create) do |relationship|
        # Set dependent to use guardian's contact info
        relationship.dependent_user.update!(
          email: relationship.guardian_user.email,
          phone: relationship.guardian_user.phone,
          phone_type: relationship.guardian_user.phone_type
        )
      end
    end
  end
end
