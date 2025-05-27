FactoryBot.define do
  factory :guardian_relationship do
    guardian_user factory: %i[user] # Or :constituent if that's more specific
    dependent_user factory: %i[user] # Or :constituent
    relationship_type { 'Parent' }

    # Trait for a specific relationship type if needed later
    # trait :legal_guardian do
    #   relationship_type { "Legal Guardian" }
    # end
  end
end
