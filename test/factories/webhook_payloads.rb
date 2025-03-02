# Factories for webhook payloads
# These factories create hash-like objects that can be used in webhook tests
FactoryBot.define do
  # Factory for email bounce payloads
  factory :webhook_bounce_payload, class: Hash do
    event { "bounce" }
    type { "permanent" }
    email { generate(:email) || "bounce@example.com" }
    bounce do
      {
        type: "permanent",
        diagnostics: "Invalid recipient"
      }
    end

    # Initialize with attributes to create a hash-like object
    initialize_with { attributes }

    # Trait for transient bounces
    trait :transient do
      bounce do
        {
          type: "transient",
          diagnostics: "Mailbox full"
        }
      end
    end

    # Trait for suppressed bounces
    trait :suppressed do
      bounce do
        {
          type: "suppressed",
          diagnostics: "Email address on suppression list"
        }
      end
    end
  end

  # Factory for email complaint payloads
  factory :webhook_complaint_payload, class: Hash do
    event { "complaint" }
    type { "abuse" }
    email { generate(:email) || "complaint@example.com" }
    complaint do
      {
        type: "abuse",
        feedback_id: "feedback123"
      }
    end

    # Initialize with attributes to create a hash-like object
    initialize_with { attributes }

    # Trait for spam complaints
    trait :spam do
      complaint do
        {
          type: "spam",
          feedback_id: "spam123"
        }
      end
    end

    # Trait for virus complaints
    trait :virus do
      complaint do
        {
          type: "virus",
          feedback_id: "virus123"
        }
      end
    end
  end

  # Factory for malformed payloads (for negative testing)
  factory :webhook_malformed_payload, class: Hash do
    event { "bounce" }
    type { "permanent" }
    email { generate(:email) || "malformed@example.com" }

    # Initialize with attributes to create a hash-like object
    initialize_with { attributes }

    # Trait for missing bounce data
    trait :missing_bounce do
      # No bounce data
    end

    # Trait for invalid bounce data
    trait :invalid_bounce do
      bounce { "not_a_hash" }
    end

    # Trait for missing complaint data
    trait :missing_complaint do
      event { "complaint" }
      # No complaint data
    end

    # Trait for invalid complaint data
    trait :invalid_complaint do
      event { "complaint" }
      complaint { "not_a_hash" }
    end

    # Trait for unknown event type
    trait :unknown_event do
      event { "unknown" }
    end
  end
end
