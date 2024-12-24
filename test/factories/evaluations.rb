FactoryBot.define do
  factory :evaluation do
    evaluator { nil }
    constituent { nil }
    evaluation_date { "2024-12-23 21:25:36" }
    evaluation_type { 1 }
    report_submitted { false }
    notes { "MyText" }
  end
end
