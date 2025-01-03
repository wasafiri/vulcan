unless Rails.env.production?
  # Clear existing data
  begin
    Policy.destroy_all
    Application.destroy_all
    User.destroy_all
  rescue => e
    Rails.logger.warn "Error during cleanup: #{e.message}"
  end

  # Create users
  Admin.create!(
    email: "admin@example.com",
    first_name: "System",
    last_name: "Administrator",
    password: "SecurePass123"
  )

  Evaluator.create!(
    email: "evaluator@example.com",
    first_name: "Primary",
    last_name: "Evaluator",
    availability_schedule: { monday: [ "9:00", "17:00" ] },
    status: :active,
    password: "SecurePass123!"
  )

  constituent = Constituent.create!(
    email: "constituent@example.com",
    first_name: "Test",
    last_name: "User",
    phone: "555-555-5555",
    date_of_birth: 30.years.ago,
    timezone: "Eastern Time (US & Canada)",
    locale: "en",
    income_proof: "Uploaded",
    residency_proof: "Uploaded",
    physical_address_1: "123 Main St",
    city: "Baltimore",
    state: "MD",
    zip_code: "21201",
    hearing_disability: true,
    vision_disability: true,
    speech_disability: true,
    home_internet_service: true,
    password: "SecurePass123!"
  )

  Vendor.create!(
    email: "vendor@example.com",
    first_name: "Equipment",
    last_name: "Provider",
    status: :approved,
    password: "SecurePass123!"
  )

  medical_provider = MedicalProvider.create!(
    email: "medical_provider@example.com",
    first_name: "Doctor",
    last_name: "Smith",
    password: "SecurePass123!"
  )

  Application.create!(
    user: constituent,
    income_verified_by: Admin.first, # Use the first admin created
    medical_provider: medical_provider,
    application_type: :new_application,
    submission_method: :online,
    status: :needs_information,
    application_date: 1.day.ago,
    received_at: 1.day.ago,
    last_activity_at: 1.day.ago,
    household_size: 3,
    annual_income: 45_000,
    income_verification_status: :failed,
    income_details: "Need additional documentation",
    residency_details: "Need proof of Maryland residency",
    current_step: "documentation_required"
  )

  # Create policies using find_or_create_by! to ensure idempotency
  {
    "max_training_sessions" => 3,
    "waiting_period_years" => 3
  }.each do |key, value|
    Policy.find_or_create_by!(key: key) do |policy|
      policy.value = value
    end
  end

  10.times do
    constituent = FactoryBot.create(:constituent)
    FactoryBot.create(:application,
      user: constituent,
      income_verified_by: Admin.first
    )
  end

  puts "Seeding completed!"
else
  puts "Production environment detected. Seeding skipped to prevent data override."
end
