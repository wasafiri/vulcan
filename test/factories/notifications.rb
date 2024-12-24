FactoryBot.define do
  factory :notification do
    recipient { nil }
    actor { nil }
    action { "MyString" }
    read_at { "2024-12-23 21:25:37" }
    metadata { "" }
    notifiable { nil }
  end
end
