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
      # Create Policies
      # ------------------------------
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
        "waiting_period_years" => 3,
        "proof_submission_rate_limit_web" => 5,
        "proof_submission_rate_limit_email" => 10,
        "proof_submission_rate_period" => 1,
        # Voucher policies
        "voucher_value_hearing_disability" => 500,
        "voucher_value_vision_disability" => 500,
        "voucher_value_speech_disability" => 500,
        "voucher_value_mobility_disability" => 500,
        "voucher_value_cognition_disability" => 500,
        "voucher_validity_period_months" => 6,
        "voucher_minimum_redemption_amount" => 10
      }

      policies.each do |key, value|
        policy = Policy.find_or_create_by!(key: key) do |p|
          p.value = value
        end
        raise "Failed to create policy #{key}" unless policy.persisted?
        raise "Policy #{key} ID not generated" unless policy.id.present?
        raise "Policy #{key} has wrong value" unless policy.value == value
      end

      # ------------------------------
      # Load Users and Applications Fixtures
      # ------------------------------
      puts "\nLoading fixtures in order..."
      fixtures_path = Rails.root.join('test/fixtures')

      # Load users first
      puts "Loading users fixture..."
      ActiveRecord::FixtureSet.create_fixtures(fixtures_path, 'users')

      # Then load applications that depend on users
      puts "Loading applications fixture..."
      ActiveRecord::FixtureSet.create_fixtures(fixtures_path, 'applications')

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
        }
        # ... rest of admin users ...
      ]
      admin_users.each do |attributes|
        user = User.find_or_create_by(email: attributes[:email]) do |u|
          u.assign_attributes(attributes)
        end
        puts "  Admin user #{user.email} created or found."
      end

      # ------------------------------
      # Attaching Files to Applications
      # ------------------------------
      puts "\nAttaching files to applications..."
      
      # First, process approved proofs in a separate transaction 
      # to ensure consistent state regardless of other applications
      puts "\nProcessing Rex Canine's application specifically..."
      rex_app = Application.joins(:user).where(users: { first_name: 'Rex', last_name: 'Canine' }).first
      
      if rex_app
        puts "Found Rex's application ##{rex_app.id}"
        puts "  Current status - Income: #{rex_app.income_proof_status}, Residency: #{rex_app.residency_proof_status}"
        puts "  Initial state - Income attached: #{rex_app.income_proof.attached?}, Residency attached: #{rex_app.residency_proof.attached?}"
        
        # Handle Rex's income proof
        if rex_app.income_proof_status == "approved" && !rex_app.income_proof.attached?
          ActiveRecord::Base.transaction do
            begin
              income_file_path = Rails.root.join('test/fixtures/files/income_proof.pdf')
              file_size = File.size(income_file_path)
              puts "  Found income proof file (#{file_size} bytes)"
              
              # Attach file using ActiveStorage
              rex_app.income_proof.attach(
                io: File.open(income_file_path),
                filename: 'income_proof.pdf',
                content_type: 'application/pdf'
              )
              
              # Verify attachment worked and save
              rex_app.reload
              puts "  Attachment state after attaching: #{rex_app.income_proof.attached?}"
              
              # Save the application to ensure consistency
              rex_app.save!
              puts "  ✓ Rex's application saved successfully with income proof attached"
            rescue => e
              puts "  ✗ Error fixing Rex's application: #{e.message}"
              puts "  #{e.backtrace.first(3).join("\n  ")}"
              raise ActiveRecord::Rollback
            end
          end
        end
      else
        puts "  ✗ Could not find Rex Canine's application"
      end
      
      # Then process all other applications
      Application.find_each do |app|
        # Skip Rex since we already processed it
        next if rex_app && app.id == rex_app.id
        
        puts "\nProcessing Application ##{app.id} (#{app.user.email})"
        puts "  Current status - Income: #{app.income_proof_status}, Residency: #{app.residency_proof_status}"
        puts "  Initial state - Income attached: #{app.income_proof.attached?}, Residency attached: #{app.residency_proof.attached?}"
        
        # Process in a transaction to ensure consistency
        ActiveRecord::Base.transaction do
          begin
            # For applications with approved or rejected status, always ensure files are attached
            if app.income_proof_status.in?(["approved", "rejected"]) && !app.income_proof.attached?
              puts "  Attaching income proof..."
              income_file_path = Rails.root.join('test/fixtures/files/income_proof.pdf')
              file_size = File.size(income_file_path)
              puts "  Found income proof file (#{file_size} bytes)"
              
              app.income_proof.attach(
                io: File.open(income_file_path),
                filename: 'income_proof.pdf',
                content_type: 'application/pdf'
              )
            end

            # For applications with approved or rejected status, always ensure files are attached
            if app.residency_proof_status.in?(["approved", "rejected"]) && !app.residency_proof.attached?
              puts "  Attaching residency proof..."
              residency_file_path = Rails.root.join('test/fixtures/files/residency_proof.pdf')
              file_size = File.size(residency_file_path)
              puts "  Found residency proof file (#{file_size} bytes)"
              
              app.residency_proof.attach(
                io: File.open(residency_file_path),
                filename: 'residency_proof.pdf',
                content_type: 'application/pdf'
              )
            end

            # Attach medical certification if needed
            if app.medical_certification_status.to_s.in?([ 'received', 'accepted' ]) && !app.medical_certification.attached?
              puts "  Attaching medical certification..."
              app.medical_certification.attach(
                io: File.open(Rails.root.join('test/fixtures/files/medical_certification_valid.pdf')),
                filename: 'medical_certification_valid.pdf',
                content_type: 'application/pdf'
              )
            end
            
            # Save the application to ensure consistency
            app.save!
            
            # Verify attachments after processing
            app.reload
            puts "  Final state:"
            puts "    Income proof attached? #{app.income_proof.attached?}"
            puts "    Residency proof attached? #{app.residency_proof.attached?}"
            puts "  ✓ Application saved successfully"
          rescue => e
            puts "  ✗ Failed to process application: #{e.message}"
            puts "  #{e.backtrace.first(3).join("\n  ")}"
            # Don't raise error here to continue processing other applications
          end
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
