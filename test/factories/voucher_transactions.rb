FactoryBot.define do
  factory :voucher_transaction do
    association :voucher
    association :vendor
    amount { 100.00 }
    status { :transaction_completed }
    processed_at { Time.current }
    reference_number { SecureRandom.hex(8).upcase }

    trait :pending do
      status { :transaction_pending }
    end

    trait :completed do
      status { :transaction_completed }
    end

    trait :failed do
      status { :transaction_failed }
    end

    trait :cancelled do
      status { :transaction_cancelled }
    end

    trait :with_invoice do
      association :invoice
    end

    trait :partial_redemption do
      amount { 50.00 }
    end

    trait :full_redemption do
      amount { voucher.remaining_value }

      after(:create) do |transaction|
        transaction.voucher.update!(
          remaining_value: 0,
          status: :redeemed
        )
      end
    end

    trait :processed_today do
      processed_at { Time.current }
    end

    trait :processed_last_week do
      processed_at { 1.week.ago }
    end

    trait :processed_last_month do
      processed_at { 1.month.ago }
    end

    # Update voucher remaining value after transaction
    after(:create) do |transaction|
      if transaction.status == "transaction_completed"
        new_remaining = transaction.voucher.remaining_value - transaction.amount
        transaction.voucher.update!(remaining_value: new_remaining)
      end
    end
  end
end
