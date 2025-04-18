FactoryBot.define do
  factory :recovery_request do
    # Create a unique user to avoid conflicts
    association :user, factory: :user, email: "recovery-user-#{SecureRandom.hex(4)}@example.com"
    status { 'pending' }
    details { 'Lost my security key during travel' }
    ip_address { '127.0.0.1' }
    user_agent { 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)' }

    trait :approved do
      status { 'approved' }
      resolved_at { Time.current }
      association :resolved_by, factory: :admin, email: "recovery-admin-#{SecureRandom.hex(4)}@example.com"
    end

    trait :rejected do
      status { 'rejected' }
      resolved_at { Time.current }
      association :resolved_by, factory: :admin, email: "recovery-admin-#{SecureRandom.hex(4)}@example.com"
    end
  end
end
