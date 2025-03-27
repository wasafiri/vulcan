# frozen_string_literal: true

FactoryBot.define do
  factory :print_queue_item do
    letter_type { 1 }
    status { 1 }
    constituent { nil }
    application { nil }
    admin { nil }
    printed_at { '2025-03-24 10:12:11' }
  end
end
