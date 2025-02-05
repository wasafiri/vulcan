# db/seeds.rb
require 'factory_bot_rails'
require 'yaml'
require 'active_record/fixtures'

unless Rails.env.production?
  begin
    ActiveRecord::Base.transaction do
      # Optionally clear existing data.
      puts "\nClearing existing data..."
      [
        Evaluation, ProofReview, Appointment, Notification, RoleCapability,
        PolicyChange, EmailTemplate, Product, Event, Policy, Application, User
      ].each do |model|
        puts "  Clearing #{model.name} records..."
        model.in_batches.destroy_all
      end

      base_date = Time.current

      # ------------------------------
      # Create Products from Fixture
      # ------------------------------
      puts "\nCreating products from fixtures..."
      product_fixture_path = Rails.root.join('test/fixtures/products.yml')
      if File.exist?(product_fixture_path)
        product_data = YAML.load_file(product_fixture_path)
        product_data.each do |key, attributes|
          puts "  Processing product #{key}..."
          # Assume that 'name' is unique for Product.
          Product.find_or_create_by(name: attributes['name']) do |product|
            clean_attributes = attributes.except('recommended_products', 'products_tried')
            product.assign_attributes(clean_attributes.transform_keys(&:to_sym))
          end
        end
        raise "No products created" if Product.count.zero?
      else
        puts "  Products fixture not found at #{product_fixture_path}"
      end

      # ------------------------------
      # Create Admin Users
      # ------------------------------
      puts "\nCreating admin users..."
      admin_users = [
        {
          type: 'Admin',
          email: 'david.bahar@maryland.gov',
          first_name: 'David',
          last_name: 'Bahar',
          password: 'password123',
          password_confirmation: 'password123',
          phone: '555-555-0001',
          date_of_birth: 44.years.ago.to_date,
          timezone: 'Eastern Time (US & Canada)',
          locale: 'en',
          hearing_disability: true,
          email_verified: true
        },
        {
          type: 'Admin',
          email: 'kevin.steffy@maryland.gov',
          first_name: 'Kevin',
          last_name: 'Steffy',
          password: 'password123',
          password_confirmation: 'password123',
          phone: '555-555-0001',
          date_of_birth: 55.years.ago.to_date,
          timezone: 'Eastern Time (US & Canada)',
          locale: 'en',
          hearing_disability: true,
          email_verified: true
        },
        {
          type: 'Admin',
          email: 'jane.hager@maryland.gov',
          first_name: 'Jane',
          last_name: 'Hager',
          password: 'password123',
          password_confirmation: 'password123',
          phone: '555-555-0001',
          date_of_birth: 55.years.ago.to_date,
          timezone: 'Eastern Time (US & Canada)',
          locale: 'en',
          hearing_disability: true,
          email_verified: true
        },
        {
          type: 'Admin',
          email: 'brandie.callender@maryland.gov',
          first_name: 'Brandie',
          last_name: 'Callender',
          password: 'password123',
          password_confirmation: 'password123',
          phone: '555-555-0001',
          date_of_birth: 35.years.ago.to_date,
          timezone: 'Eastern Time (US & Canada)',
          locale: 'en',
          hearing_disability: true,
          email_verified: true
        }
      ]
      admin_users.each do |attributes|
        user = User.find_or_create_by(email: attributes[:email]) do |u|
          u.assign_attributes(attributes)
        end
        puts "  Admin user #{user.email} created or found."
      end

      # ------------------------------
      # Create Constituent Users
      # ------------------------------
      puts "\nCreating constituent users..."
      constituent_users = [
        {
          type: 'Constituent',
          email: 'john.doe@example.com',
          first_name: 'John',
          last_name: 'Doe',
          password: 'password123',
          password_confirmation: 'password123',
          phone: '555-555-0002',
          date_of_birth: 45.years.ago.to_date,
          physical_address_1: '123 Main St',
          city: 'Baltimore',
          state: 'MD',
          zip_code: '21201',
          hearing_disability: true,
          timezone: 'Eastern Time (US & Canada)',
          locale: 'en',
          email_verified: true
        },
        {
          type: 'Constituent',
          email: 'jane.doe@example.com',
          first_name: 'Jane',
          last_name: 'Doe',
          password: 'password123',
          password_confirmation: 'password123',
          phone: '555-555-0002',
          date_of_birth: 25.years.ago.to_date,
          physical_address_1: '124 Main St',
          city: 'Baltimore',
          state: 'MD',
          zip_code: '21201',
          mobility_disability: true,
          timezone: 'Eastern Time (US & Canada)',
          locale: 'en',
          email_verified: true
        },
        {
          type: 'Constituent',
          email: 'kenneth.klein@example.com',
          first_name: 'Kenneth',
          last_name: 'Klein',
          password: 'password123',
          password_confirmation: 'password123',
          phone: '555-555-0002',
          date_of_birth: 25.years.ago.to_date,
          physical_address_1: '125 Main St',
          city: 'Baltimore',
          state: 'MD',
          zip_code: '21201',
          cognition_disability: true,
          timezone: 'Eastern Time (US & Canada)',
          locale: 'en',
          email_verified: true
        },
        {
          type: 'Constituent',
          email: 'steven.cooper@example.com',
          first_name: 'Steven',
          last_name: 'Cooper',
          password: 'password123',
          password_confirmation: 'password123',
          phone: '555-555-0002',
          date_of_birth: 25.years.ago.to_date,
          physical_address_1: '126 Main St',
          city: 'Baltimore',
          state: 'MD',
          zip_code: '21201',
          speech_disability: true,
          timezone: 'Eastern Time (US & Canada)',
          locale: 'en',
          email_verified: true
        },
        # New Constituent User
        {
          type: 'Constituent',
          email: 'alex.smith@example.com',
          first_name: 'Alex',
          last_name: 'Smith',
          password: 'password123',
          password_confirmation: 'password123',
          phone: '555-555-0003',
          date_of_birth: 30.years.ago.to_date,
          physical_address_1: '200 Elm Street',
          city: 'Baltimore',
          state: 'MD',
          zip_code: '21202',
          timezone: 'Eastern Time (US & Canada)',
          locale: 'en',
          email_verified: true
        }
      ]
      constituent_users.each do |attributes|
        user = User.find_or_create_by(email: attributes[:email]) do |u|
          u.assign_attributes(attributes)
        end
        puts "  Constituent user #{user.email} created or found."
      end

      # ------------------------------
      # Create Evaluator Users
      # ------------------------------
      puts "\nCreating evaluator users..."
      evaluator_users = [
        {
          type: 'Evaluator',
          email: 'betsya.hein@maryland.gov',
          first_name: 'Betsy',
          last_name: 'Hein',
          password: 'password123',
          password_confirmation: 'password123',
          phone: '555-555-0003',
          date_of_birth: 50.years.ago.to_date,
          timezone: 'Eastern Time (US & Canada)',
          locale: 'en',
          email_verified: true,
          status: 'active',
          availability_schedule: {
            monday: [ "9:00", "17:00" ],
            wednesday: [ "9:00", "17:00" ],
            friday: [ "9:00", "17:00" ]
          }
        }
      ]
      evaluator_users.each do |attributes|
        user = User.find_or_create_by(email: attributes[:email]) do |u|
          u.assign_attributes(attributes)
        end
        puts "  Evaluator user #{user.email} created or found."
      end

      # ------------------------------
      # Create Vendor Users
      # ------------------------------
      puts "\nCreating vendor users..."
      vendor_users = [
        {
          type: 'Vendor',
          email: 'raz@testemail.com',
          first_name: 'Raz',
          last_name: 'Vendor',
          password: 'password123',
          password_confirmation: 'password123',
          phone: '555-555-0004',
          date_of_birth: 50.years.ago.to_date,
          timezone: 'Eastern Time (US & Canada)',
          locale: 'en',
          email_verified: true,
          status: 'approved'
        }
      ]
      vendor_users.each do |attributes|
        user = User.find_or_create_by(email: attributes[:email]) do |u|
          u.assign_attributes(attributes)
        end
        puts "  Vendor user #{user.email} created or found."
      end

      # ------------------------------
      # Create Primary Constituent for Applications
      # ------------------------------
      puts "\nCreating primary constituent for applications..."
      primary_constituent = User.find_or_create_by(email: "constituent@example.com") do |user|
        user.assign_attributes(
          type: 'Constituent',
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
          password: "SecurePass123!",
          password_confirmation: "SecurePass123!"
        )
      end
      puts "  Primary constituent #{primary_constituent.email} created or found."

      # ------------------------------
      # Load Applications Fixture
      # ------------------------------
      # (Ensure your applications fixture uses user_id and no keys for attachments.)
      applications_fixture_path = Rails.root.join('test/fixtures/applications.yml')
      if File.exist?(applications_fixture_path)
        puts "\nLoading applications fixture from #{applications_fixture_path}..."
        ActiveRecord::FixtureSet.create_fixtures(Rails.root.join('test/fixtures'), 'applications')
        puts "Applications fixture loaded."
      else
        puts "\nApplications fixture not found at #{applications_fixture_path}."
      end

      # ------------------------------
      # Attach Proof Files to Applications via Active Storage
      # ------------------------------
      puts "\nAttaching proof files to applications..."
      Application.find_each do |app|
        # Attach an income proof if not already attached.
        unless app.income_proof.attached?
          app.income_proof.attach(
            io: File.open(Rails.root.join('test/fixtures/files/income_proof.pdf')),
            filename: 'income_proof.pdf',
            content_type: 'application/pdf'
          )
          puts "  Attached income proof for Application ##{app.id}"
        end

        # Attach a residency proof if not already attached.
        unless app.residency_proof.attached?
          app.residency_proof.attach(
            io: File.open(Rails.root.join('test/fixtures/files/residency_proof.pdf')),
            filename: 'residency_proof.pdf',
            content_type: 'application/pdf'
          )
          puts "  Attached residency proof for Application ##{app.id}"
        end
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
