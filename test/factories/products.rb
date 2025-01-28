FactoryBot.define do
  unless FactoryBot.factories.registered?(:product)
    factory :product do
      name { "My Product" }
      description { "Some product description" }
      manufacturer { "Acme" }
      model_number { "ABC123" }
      device_types { [ "Smartphone" ] }  # Must be an array
      archived_at { nil }
      documentation_url { "https://example.com/docs" }

      factory :braille_device do
        name { "Braille Device" }
        manufacturer { "HIMS" }
        model_number { "BrailleSense Polaris" }
        device_types { [ "Braille Device" ] }
      end

      factory :apple_iphone do
        name { "Apple iPhone 14" }
        manufacturer { "Apple" }
        model_number { "A2649" }
        device_types { [ "Smartphone" ] }
      end
    end
  end
end
