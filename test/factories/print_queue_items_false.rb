# frozen_string_literal: true

FactoryBot.define do
  factory :print_queue_item do
    letter_type { :income_proof_rejected }
    status { :printed }

    # Create unique users to avoid email/phone conflicts
    constituent do
      create(:constituent,
             email: "pqi_constituent_#{Time.current.to_f.to_s.gsub('.', '_')}@example.com",
             phone: "555-#{Time.current.to_i.to_s.last(3)}-#{rand(1000..9999)}")
    end

    application do
      create(:application,
             user: create(:constituent,
                          email: "pqi_app_user_#{Time.current.to_f.to_s.gsub('.', '_')}@example.com",
                          phone: "555-#{Time.current.to_i.to_s.last(3)}-#{rand(1000..9999)}"))
    end

    admin do
      create(:admin,
             email: "pqi_admin_#{Time.current.to_f.to_s.gsub('.', '_')}@example.com",
             phone: "555-#{Time.current.to_i.to_s.last(3)}-#{rand(1000..9999)}")
    end

    printed_at { Time.current }

    after(:build) do |print_queue_item|
      # Attach a sample PDF file for the pdf_letter requirement
      print_queue_item.pdf_letter.attach(
        io: Rails.root.join('test/fixtures/files/sample.pdf').open,
        filename: 'sample_letter.pdf',
        content_type: 'application/pdf'
      )
    end

    trait :pending do
      status { :pending }
      printed_at { nil }
      admin { nil }
    end

    trait :canceled do
      status { :canceled }
      printed_at { nil }
    end

    trait :account_created do
      letter_type { :account_created }
    end

    trait :application_approved do
      letter_type { :application_approved }
    end
  end
end
