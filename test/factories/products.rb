# frozen_string_literal: true

FactoryBot.define do
  factory :product do
    sequence(:name) { |n| "Test Product #{n}" }
    description { 'A detailed description of this assistive technology product.' }
    price { 299.99 }
    quantity { 100 }
    manufacturer { 'Assistive Tech Inc.' }
    model_number { "AT-#{SecureRandom.hex(4).upcase}" }
    features { 'High quality, durable, user-friendly interface' }
    compatibility_notes { 'Compatible with most operating systems' }
    documentation_url { 'https://example.com/docs' }
    device_types { ['Tablet'] } # Using proper capitalization/valid values

    trait :archived do
      archived_at { 1.day.ago }
    end

    trait :low_stock do
      quantity { 3 }
    end

    trait :mobile do
      device_types { ['Mobile'] }
    end

    trait :tablet do
      device_types { ['Tablet'] }
    end
  end
end
