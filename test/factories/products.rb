FactoryBot.define do
  factory :product do
    name { "MyString" }
    description { "MyText" }
    price { "9.99" }
    quantity { 1 }
    device_type { "MyString" }
    archived_at { "2024-12-23 21:25:35" }
    user { nil }
  end
end
