# test/factories/evaluations.rb
FactoryBot.define do
  unless FactoryBot.factories.registered?(:evaluation)
    factory :evaluation do
      association :evaluator, factory: :evaluator
      association :constituent, factory: :constituent
      # Remove the application association since it will be provided

      evaluation_date { Date.today }
      evaluation_type { :initial }
      report_submitted { false }
      notes { "Initial evaluation notes." }
      status { :pending }

      trait :completed do
        report_submitted { true }
        status { :completed }
        notes { "Evaluation completed successfully." }
      end

      trait :rejected do
        report_submitted { false }
        status { :rejected }
        notes { "Evaluation rejected due to insufficient documentation." }
      end
    end
  end
end
