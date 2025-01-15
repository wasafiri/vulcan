FactoryBot.define do
  unless FactoryBot.factories.registered?(:notification)
    factory :notification do
      association :recipient, factory: :user
      association :actor, factory: :user
      association :notifiable, factory: :application

      action { "proof_submitted" }
      read_at { nil }
      metadata { {
        proof_types: [ "income" ],
        application_id: nil
      } }

      trait :read do
        read_at { Time.current }
      end

      trait :proof_rejected do
        action { "proof_rejected" }
        metadata { {
          proof_types: [ "income" ],
          rejection_reason: "Document unclear"
        } }
      end

      trait :bounced_email do
        action { "medical_provider_email_bounced" }
        metadata { {
          email: "doctor@example.com",
          bounce_type: "permanent",
          diagnostics: "Invalid recipient"
        } }
      end

      after(:create) do |notification|
        if notification.notifiable.is_a?(Application) && notification.metadata["application_id"].nil?
          notification.update!(
            metadata: notification.metadata.merge(
              "application_id" => notification.notifiable.id
            )
          )
        end
      end
    end
  end
end
