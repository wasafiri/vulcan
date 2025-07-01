# frozen_string_literal: true

FactoryBot.define do
  factory :vendor, class: 'Users::Vendor' do
    type { 'Users::Vendor' }
    sequence(:email) { |n| "vendor#{n}@example.com" }
    password { 'password123' }
    first_name { 'Test' }
    last_name { 'Vendor' }
    sequence(:business_name) { |n| "Test Business #{n}" }
    sequence(:business_tax_id) { |n| "12345#{n.to_s.rjust(4, '0')}" }
    status { :pending }
    verified { true }

    trait :approved do
      status { :approved }
      terms_accepted_at { 1.day.ago }
      after(:create) do |vendor|
        vendor.w9_form.attach(
          io: Rails.root.join('test/fixtures/files/sample_w9.txt').open,
          filename: 'w9.txt',
          content_type: 'text/plain'
        )
      end
    end

    trait :pending do
      status { :pending }
    end

    trait :suspended do
      status { :suspended }
    end

    trait :with_w9 do
      after(:create) do |vendor|
        vendor.w9_form.attach(
          io: Rails.root.join('test/fixtures/files/sample_w9.pdf').open,
          filename: 'w9.pdf',
          content_type: 'application/pdf'
        )
        vendor.update(w9_status: :pending_review)
      end
    end

    trait :with_transactions do
      transient do
        transaction_count { 3 }
      end

      after(:create) do |vendor, evaluator|
        create_list(:voucher_transaction, evaluator.transaction_count,
                    vendor: vendor,
                    status: :transaction_completed)
      end
    end

    trait :with_pending_invoice do
      after(:create) do |vendor|
        create(:invoice, :with_transactions,
               vendor: vendor,
               status: :invoice_pending)
      end
    end

    trait :with_paid_invoice do
      after(:create) do |vendor|
        create(:invoice, :with_transactions,
               vendor: vendor,
               status: :invoice_paid,
               paid_at: Time.current)
      end
    end

    trait :with_terms_accepted do
      terms_accepted_at { 1.day.ago }
    end

    trait :with_full_profile do
      business_name { 'Complete Business' }
      business_tax_id { '123456789' }
      phone { '555-123-4567' }
      terms_accepted_at { 1.day.ago }
      after(:create) do |vendor|
        vendor.w9_form.attach(
          io: Rails.root.join('test/fixtures/files/sample_w9.txt').open,
          filename: 'w9.txt',
          content_type: 'text/plain'
        )
      end
    end
  end
end
