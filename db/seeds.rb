require 'factory_bot_rails'

unless Rails.env.production?
  begin
    ActiveRecord::Base.transaction do
      # Clear existing data
      puts "\nClearing existing data..."
      [
        Evaluation, ProofReview, Appointment, Notification, RoleCapability,
        PolicyChange, EmailTemplate, Product, Event, Policy, Application, User
      ].each do |model|
        puts "  Clearing #{model.name} records..."
        model.in_batches.destroy_all
      end

      base_date = Time.current

      # Create admin first since other records will reference it
      puts "\nCreating admin user..."
      admin = FactoryBot.create(:admin, {
        email: "admin@example.com",
        first_name: "System",
        last_name: "Administrator",
        password: "SecurePass123"
      })
      raise "Failed to create admin" unless admin.persisted?
      raise "Admin ID not generated" unless admin.id.present?

      # Create evaluators
      puts "\nCreating evaluators..."
      evaluators = 3.times.map do |i|
        evaluator = FactoryBot.create(:evaluator, {
          email: "evaluator#{i + 1}@example.com",
          first_name: "Evaluator#{i + 1}",
          last_name: "LastName#{i + 1}",
          availability_schedule: { monday: [ "9:00", "17:00" ], tuesday: [ "10:00", "16:00" ] },
          status: :active,
          password: "SecurePass123!"
        })
        raise "Failed to create evaluator #{i + 1}" unless evaluator.persisted?
        raise "Evaluator #{i + 1} ID not generated" unless evaluator.id.present?
        evaluator
      end
      raise "No evaluators were created" if evaluators.empty?

      # Create primary constituent
      puts "\nCreating primary constituent..."
      constituent = FactoryBot.create(:constituent, :with_disabilities, {
        email: "constituent@example.com",
        first_name: "Test",
        last_name: "User",
        phone: "555-555-5555",
        date_of_birth: base_date - 25.years,
        timezone: "Eastern Time (US & Canada)",
        locale: "en",
        physical_address_1: "123 Main St",
        city: "Baltimore",
        state: "MD",
        zip_code: "21201",
        home_internet_service: true,
        password: "SecurePass123!"
      })
      raise "Failed to create primary constituent" unless constituent.persisted?
      raise "Constituent ID not generated" unless constituent.id.present?
      raise "Constituent disabilities not set" unless
        constituent.hearing_disability ||
        constituent.vision_disability ||
        constituent.speech_disability ||
        constituent.mobility_disability ||
        constituent.cognition_disability

      # Create vendor
      puts "\nCreating vendor..."
      vendor = FactoryBot.create(:vendor, {
        email: "vendor@example.com",
        first_name: "Equipment",
        last_name: "Provider",
        status: :approved,
        password: "SecurePass123!"
      })
      raise "Failed to create vendor" unless vendor.persisted?
      raise "Vendor ID not generated" unless vendor.id.present?

      # Create policies
      puts "\nCreating policies..."
      policies = {
        "fpl_modifier_percentage" => 400,
        "fpl_1_person" => 15_060,
        "fpl_2_person" => 20_440,
        "fpl_3_person" => 25_820,
        "fpl_4_person" => 31_200,
        "fpl_5_person" => 36_580,
        "fpl_6_person" => 41_960,
        "fpl_7_person" => 47_340,
        "fpl_8_person" => 52_720,
        "max_training_sessions" => 3,
        "waiting_period_years" => 3
      }

      policies.each do |key, value|
        policy = Policy.find_or_create_by!(key: key) do |p|
          p.value = value
        end
        raise "Failed to create policy #{key}" unless policy.persisted?
        raise "Policy #{key} ID not generated" unless policy.id.present?
        raise "Policy #{key} has wrong value" unless policy.value == value
      end

      # Verify required records exist
      raise "Missing required admin user" unless admin&.id
      raise "Missing required constituent" unless constituent&.id
      raise "No evaluators available" if evaluators.empty?

      # **Create Products Before Applications and Evaluations**
      puts "\nCreating products..."
      products = [
        FactoryBot.create(:product, name: "Generic Product"),
        FactoryBot.create(:braille_device),
        FactoryBot.create(:apple_iphone)
      ]
      raise "Failed to create products" unless products.all?(&:persisted?)
      puts "Created products: #{products.map(&:name).join(', ')}"

      # **Create Applications with Approved Status**
      puts "\nCreating applications with approved status..."
      10.times do |i|
        print "  Creating approved application #{i + 1}... "

        first_names = [ "James", "Mary", "John", "Patricia", "Robert", "Jennifer" ]
        last_names = [ "Smith", "Johnson", "Williams", "Brown", "Jones" ]

        # Create a new constituent for each application
        new_constituent = FactoryBot.create(:constituent, :with_disabilities, {
          email: "constituent_approved_#{i + 1}@example.com",
          first_name: first_names.sample,
          last_name: last_names.sample
        })
        raise "Failed to create constituent for approved application #{i + 1}" unless new_constituent.persisted?

        # Create approved application
        application = FactoryBot.create(:application, :completed, {
          user: new_constituent,
          income_verified_by: admin,
          application_date: base_date - 4.years,
          terms_accepted: true,
          information_verified: true,
          medical_release_authorized: true
        })
        raise "Failed to create approved application #{i + 1}" unless application.persisted?
        raise "Proof files not attached for application #{i + 1}" unless
          application.income_proof.attached? && application.residency_proof.attached?

        # Select a random evaluator
        evaluator = evaluators.sample

        # Create evaluation with notes
        evaluation = FactoryBot.create(:evaluation, :completed, {
          evaluator: evaluator,
          constituent: new_constituent,
          application: application,
          evaluation_date: base_date - 3.years,
          evaluation_type: :initial,
          report_submitted: true,
          notes: "Initial evaluation completed.",
          status: :completed
          # 'last_evaluation_completed_at' is not being set manually; handled by the Application model method
        })
        raise "Failed to create evaluation for approved application #{i + 1}" unless evaluation.persisted?

        puts "done"
      end

      # **Create Applications with Rejected Status**
      puts "\nCreating applications with rejected status..."
      5.times do |i|
        print "  Creating rejected application #{i + 1}... "

        application = FactoryBot.create(:application, :rejected, {
          user: constituent,
          income_verified_by: admin,
          application_date: base_date - 4.years,
          terms_accepted: true,
          information_verified: true,
          medical_release_authorized: true
        })
        raise "Failed to create rejected application #{i + 1}" unless application.persisted?
        raise "Proof files not attached for rejected application #{i + 1}" unless
          application.income_proof.attached? && application.residency_proof.attached?

        # Select a random evaluator
        evaluator = evaluators.sample

        # Create evaluation with notes
        evaluation = FactoryBot.create(:evaluation, :completed, {
          evaluator: evaluator,
          constituent: constituent,
          application: application,
          evaluation_date: base_date - 3.years,
          evaluation_type: :initial,
          report_submitted: false,
          notes: "Initial evaluation rejected due to insufficient documentation.",
          status: :completed
        })
        raise "Failed to create evaluation for rejected application #{i + 1}" unless evaluation.persisted?

        puts "done"
      end

      # **Create Applications with Archived Status**
      puts "\nCreating applications with archived status..."
      10.times do |i|
        print "  Creating archived application #{i + 1}... "

        application = FactoryBot.create(:application, :archived, {
          user: constituent,
          income_verified_by: admin,
          application_date: base_date - 8.years,
          terms_accepted: true,
          information_verified: true,
          medical_release_authorized: true
        })
        raise "Failed to create archived application #{i + 1}" unless application.persisted?
        raise "Proof files not attached for archived application #{i + 1}" unless
          application.income_proof.attached? && application.residency_proof.attached?

        # Select a random evaluator
        evaluator = evaluators.sample

        # Create evaluation with notes
        evaluation = FactoryBot.create(:evaluation, :completed, {
          evaluator: evaluator,
          constituent: constituent,
          application: application,
          evaluation_date: base_date - 7.years,
          evaluation_type: :renewal,
          report_submitted: true,
          notes: "Renewal evaluation completed.",
          status: :completed
        })
        raise "Failed to create evaluation for archived application #{i + 1}" unless evaluation.persisted?

        puts "done"
      end

      # **Create In-Progress Applications with Rejected Proofs**
      puts "\nCreating in-progress applications with rejected proofs..."
      5.times do |i|
        print "  Creating in-progress application with rejected proofs #{i + 1}... "

        # Create constituent first
        new_constituent = FactoryBot.create(:constituent, :with_disabilities, {
          email: "constituent_rejected_proofs_#{i + 1}@example.com",
          first_name: "Constituent_RejectedProofs#{i + 1}",
          last_name: "User#{i + 1}"
        })
        raise "Failed to create constituent for rejected proofs application #{i + 1}" unless new_constituent.persisted?

        # Create application using the new constituent
        application = FactoryBot.create(:application, :in_progress_with_rejected_proofs, {
          user: new_constituent,
          application_date: base_date - 1.month
        })
        raise "Failed to create in-progress application with rejected proofs #{i + 1}" unless application.persisted?
        raise "Proof files not attached for in-progress application #{i + 1}" unless
          application.income_proof.attached? && application.residency_proof.attached?

        # Create evaluation with required fields
        evaluation = FactoryBot.create(:evaluation, :completed, {
          evaluator: evaluators.sample,
          constituent: new_constituent,
          application: application,
          evaluation_date: base_date - 1.month,
          evaluation_type: :initial,
          report_submitted: false,
          notes: "In-progress evaluation with rejected proofs.",
          status: :completed
        })
        raise "Failed to create evaluation for in-progress application with rejected proofs #{i + 1}" unless evaluation.persisted?

        puts "done"
      end

      # **Create In-Progress Applications with Approved Proofs**
      puts "\nCreating in-progress applications with approved proofs..."
      5.times do |i|
        print "  Creating in-progress application with approved proofs #{i + 1}... "

        # Create constituent first
        new_constituent = FactoryBot.create(:constituent, :with_disabilities, {
          email: "constituent_approved_proofs_#{i + 1}@example.com",
          first_name: "Constituent_ApprovedProofs#{i + 1}",
          last_name: "User#{i + 1}"
        })
        raise "Failed to create constituent for approved proofs application #{i + 1}" unless new_constituent.persisted?

        # Create application using the new constituent
        application = FactoryBot.create(:application, :in_progress_with_approved_proofs, {
          user: new_constituent,
          application_date: base_date - 1.month
        })
        raise "Failed to create in-progress application with approved proofs #{i + 1}" unless application.persisted?
        raise "Proof files not attached for in-progress application #{i + 1}" unless
          application.income_proof.attached? && application.residency_proof.attached?

        # Create evaluation with required fields
        evaluation = FactoryBot.create(:evaluation, :completed, {
          evaluator: evaluators.sample,
          constituent: new_constituent,
          application: application,
          evaluation_date: base_date - 1.month,
          evaluation_type: :initial,
          report_submitted: true,
          notes: "In-progress evaluation with approved proofs.",
          status: :completed
        })
        raise "Failed to create evaluation for in-progress application with approved proofs #{i + 1}" unless evaluation.persisted?

        puts "done"
      end
    end
  rescue StandardError => e
    puts "\nSeeding failed: #{e.message}"
    puts "Backtrace:"
    e.backtrace.first(10).each { |line| puts line }
    exit 1
  else
    puts "\nSeeding completed successfully!" unless Rails.env.production?
  end
else
  puts "Production environment detected. Seeding skipped to prevent data override."
end
