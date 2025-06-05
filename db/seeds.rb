# frozen_string_literal: true

require 'factory_bot_rails'
require 'yaml'
require 'active_record/fixtures'

# Helper method to conditionally output messages
def seed_puts(message)
  puts message if ENV['VERBOSE_TESTS'] || Rails.env.development?
end

# Helper method for error messages (always shown)
def seed_error(message)
  puts "[SEED ERROR] #{message}"
end

# Helper method for success messages (only in verbose mode)
def seed_success(message)
  puts message if ENV['VERBOSE_TESTS']
end

if Rails.env.production?
  puts 'Production environment detected. Seeding skipped to prevent data override.'
else
  begin
    ActiveRecord::Base.transaction do
      # Optionally clear existing data.
      seed_puts 'Clearing existing data...'

      # Clear sessions first to avoid foreign key constraint violations
      seed_puts '  Clearing Session records...'
      Session.in_batches(of: 100).delete_all

      # Then clear other models
      [
        Evaluation, ProofReview, Notification, RoleCapability,
        PolicyChange, EmailTemplate, Product, Event, Policy, Application, User
      ].each do |model|
        seed_puts "  Clearing #{model.name} records..."
        # Delete records in small batches to avoid memory issues
        model.in_batches(of: 100).delete_all
      end

      # ------------------------------
      # Create Products from Fixture
      # ------------------------------
      seed_puts 'Creating products from fixtures...'
      product_fixture_path = Rails.root.join('test/fixtures/products.yml')
      if File.exist?(product_fixture_path)
        product_data = YAML.load_file(product_fixture_path)
        product_data.each do |key, attributes|
          seed_puts "  Processing product #{key}..."
          # Assume that 'name' is unique for Product.
          Product.find_or_create_by(name: attributes['name']) do |product|
            clean_attributes = attributes.except('recommended_products', 'products_tried')
            product.assign_attributes(clean_attributes.transform_keys(&:to_sym))
          end
        end
        raise 'No products created' if Product.count.zero?
      else
        seed_error "Products fixture not found at #{product_fixture_path}"
      end

      # ------------------------------
      # Create Policies
      # ------------------------------
      seed_puts 'Creating policies...'
      policies = {
        'fpl_modifier_percentage' => 400,
        'fpl_1_person' => 15_650,
        'fpl_2_person' => 21_150,
        'fpl_3_person' => 26_650,
        'fpl_4_person' => 32_150,
        'fpl_5_person' => 37_650,
        'fpl_6_person' => 43_150,
        'fpl_7_person' => 48_650,
        'fpl_8_person' => 54_150,
        'max_training_sessions' => 3,
        'waiting_period_years' => 3,
        'proof_submission_rate_limit_web' => 5,
        'proof_submission_rate_limit_email' => 10,
        'proof_submission_rate_period' => 1,
        # Voucher policies
        'voucher_value_hearing_disability' => 500,
        'voucher_value_vision_disability' => 500,
        'voucher_value_speech_disability' => 500,
        'voucher_value_mobility_disability' => 500,
        'voucher_value_cognition_disability' => 500,
        'voucher_validity_period_months' => 6,
        'voucher_minimum_redemption_amount' => 10
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
      seed_puts 'Loading fixtures in order...'
      fixtures_path = Rails.root.join('test/fixtures')

      # Load users first
      seed_puts 'Loading users fixture via ActiveRecord models...'
      user_fixture_file = fixtures_path.join('users.yml')
      if File.exist?(user_fixture_file)
        # Disable uniqueness validation on plaintext email column for seeding
        User._validators[:email].reject! { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
        user_data = YAML.safe_load(ERB.new(File.read(user_fixture_file)).result, permitted_classes: [Date, DateTime, Time])
        users_map = {}
        user_data.each do |key, attributes|
          seed_puts "  Creating user #{key}..."
          # Map vendor fixture status 'approved' to valid user status 'active'
          attributes['status'] = 'active' if attributes['status'] == 'approved'
          user = User.new
          attributes.each do |attr, value|
            setter = "#{attr}="
            user.send(setter, value) if user.respond_to?(setter)
          end
          user.save!(validate: false)
          users_map[key] = user
        end
      else
        seed_error "Users fixture not found at #{user_fixture_file}"
      end

      # Then load applications that depend on users
      seed_puts 'Loading applications fixture via ActiveRecord models...'
      app_fixture_file = fixtures_path.join('applications.yml')
      if File.exist?(app_fixture_file)
        app_data = YAML.safe_load(ERB.new(File.read(app_fixture_file)).result, permitted_classes: [Date, DateTime, Time])
        app_data.each do |key, attributes|
          seed_puts "  Creating application #{key}..."
          # Map legacy fixture status "in_review" to valid enum "in_progress"
          attributes['status'] = 'in_progress' if attributes['status'] == 'in_review'
          # Map fixture submission_method values to valid enum keys
          attributes['submission_method'] = 'online' if attributes['submission_method'] == 'web'
          # Map fixture user reference to user_id
          if attributes['user']
            user_key = attributes.delete('user')
            attributes['user_id'] = users_map[user_key]&.id
          end
          filtered_attributes = attributes.slice(*Application.attribute_names)
          app = Application.new(filtered_attributes)
          app.save!(validate: false)
        end
      else
        seed_error "Applications fixture not found at #{app_fixture_file}"
      end

      # Disable invoice payment notifications during seeding
      Invoice.skip_callback(:save, :after, :send_payment_notification)
      # Then load invoices that depend on users (vendors)
      seed_puts 'Loading invoices fixture via ActiveRecord models...'
      invoice_fixture_file = fixtures_path.join('invoices.yml')
      if File.exist?(invoice_fixture_file)
        invoice_data = YAML.safe_load(ERB.new(File.read(invoice_fixture_file)).result, permitted_classes: [Date, DateTime, Time])
        invoices_map = {}
        invoice_data.each do |key, attributes|
          seed_puts "  Creating invoice #{key}..."
          # No status mapping needed; fixtures use Invoice enum keys
          # Map vendor fixture reference to vendor_id
          if attributes['vendor']
            vendor_key = attributes.delete('vendor')
            attributes['vendor_id'] = users_map[vendor_key]&.id
          end
          filtered_attributes = attributes.slice(*Invoice.attribute_names)
          invoice = Invoice.new(filtered_attributes)
          invoice.save!(validate: false)
          invoices_map[key] = invoice
        end
      else
        seed_error "Invoices fixture not found at #{invoice_fixture_file}"
      end

      # ------------------------------
      # Seed Email Templates
      # ------------------------------
      seed_puts 'Seeding email templates...'
      load Rails.root.join('db/seeds/email_templates.rb')

      # ------------------------------
      # Ensure storage directory exists
      # ------------------------------
      seed_puts 'Ensuring storage directory exists...'
      storage_dir = Rails.root.join('storage')
      FileUtils.mkdir_p(storage_dir) unless storage_dir

      # ------------------------------
      # Attaching Files to Applications
      # ------------------------------
      seed_puts 'Attaching files to applications...'

      # First, process Rex Canine application specifically
      seed_puts 'Processing Rex Canine application specifically...'
      rex_app = Application.joins(:user).where(users: { first_name: 'Rex', last_name: 'Canine' }).first

      if rex_app
        seed_puts "Found Rex's application ##{rex_app.id}"
        seed_puts "  Current status - Income: #{rex_app.income_proof_status}, Residency: #{rex_app.residency_proof_status}"
        seed_puts "  Initial state - Income attached: #{rex_app.income_proof.attached?}, Residency attached: #{rex_app.residency_proof.attached?}"

        # For Rex's application, handle each proof separately
        if rex_app.income_proof_status == 'approved' && !rex_app.income_proof.attached?
          seed_puts '  Attaching income proof...'
          income_file_path = Rails.root.join('test/fixtures/files/income_proof.pdf')
          if File.exist?(income_file_path)
            rex_app.income_proof.attach(
              io: File.open(income_file_path),
              filename: 'income_proof.pdf',
              content_type: 'application/pdf'
            )
            # Use save instead of save! to avoid validation errors
            rex_app.save
            seed_success '  ✓ Income proof attached successfully'
          else
            seed_error "Income proof file not found at #{income_file_path}"
          end
        end

        # Also handle residency proof if needed
        if rex_app.residency_proof_status.in?(%w[approved rejected]) && !rex_app.residency_proof.attached?
          seed_puts '  Attaching residency proof...'
          residency_file_path = Rails.root.join('test/fixtures/files/residency_proof.pdf')
          if File.exist?(residency_file_path)
            rex_app.residency_proof.attach(
              io: File.open(residency_file_path),
              filename: 'residency_proof.pdf',
              content_type: 'application/pdf'
            )
            # Use save instead of save! to avoid validation errors
            rex_app.save
            seed_success '  ✓ Residency proof attached successfully'
          else
            seed_error "Residency proof file not found at #{residency_file_path}"
          end
        end
      else
        seed_error 'Could not find Rex Canine application'
      end

      # Then process all other applications
      Application.find_each do |app|
        # Skip Rex since we already processed it
        next if rex_app && app.id == rex_app.id

        # Skip applications with missing users
        if app.user.nil?
          seed_error "Skipping Application ##{app.id} - Missing user reference"
          next
        end

        seed_puts "  Processing Application ##{app.id} (#{app.user.email})"

        # Handle each proof type separately with its own save operation

        # Process income proof
        if app.income_proof_status.in?(%w[approved rejected]) && !app.income_proof.attached?
          seed_puts '    Attaching income proof...'
          income_file_path = Rails.root.join('test/fixtures/files/income_proof.pdf')
          if File.exist?(income_file_path)
            app.income_proof.attach(
              io: File.open(income_file_path),
              filename: 'income_proof.pdf',
              content_type: 'application/pdf'
            )
            # Use save instead of save! to avoid validation errors
            app.save
            seed_success '    ✓ Income proof attached'
          else
            seed_error "Income proof file not found at #{income_file_path}"
          end
        end

        # Process residency proof
        if app.residency_proof_status.in?(%w[approved rejected]) && !app.residency_proof.attached?
          seed_puts '    Attaching residency proof...'
          residency_file_path = Rails.root.join('test/fixtures/files/residency_proof.pdf')
          if File.exist?(residency_file_path)
            app.residency_proof.attach(
              io: File.open(residency_file_path),
              filename: 'residency_proof.pdf',
              content_type: 'application/pdf'
            )
            # Use save instead of save! to avoid validation errors
            app.save
            seed_success '    ✓ Residency proof attached'
          else
            seed_error "Residency proof file not found at #{residency_file_path}"
          end
        end

        # Process medical certification
        if app.medical_certification_status.to_s.in?(%w[received accepted]) && !app.medical_certification.attached?
          seed_puts '    Attaching medical certification...'
          medical_file_path = Rails.root.join('test/fixtures/files/medical_certification_valid.pdf')
          if File.exist?(medical_file_path)
            app.medical_certification.attach(
              io: File.open(medical_file_path),
              filename: 'medical_certification_valid.pdf',
              content_type: 'application/pdf'
            )
            # Use save instead of save! to avoid validation errors
            app.save
            seed_success '    ✓ Medical certification attached'
          else
            seed_error "Medical certification file not found at #{medical_file_path}"
          end
        end
      end

      # ------------------------------
      # Verify and Fix Missing Files
      # ------------------------------
      seed_puts 'Verifying all application attachments...'

      Application.find_each do |app|
        fixed_files = []

        # Check income proof
        if app.income_proof.attached?
          blob = app.income_proof.blob
          disk_key = blob.key
          disk_path = Rails.root.join('storage', disk_key[0, 2], disk_key[2, 2], disk_key)

          unless File.exist?(disk_path)
            seed_puts "  Fixing missing income proof for Application ##{app.id}..."

            # Create directory structure if needed
            dir_path = Rails.root.join('storage', disk_key[0, 2], disk_key[2, 2])
            FileUtils.mkdir_p(dir_path)

            # Copy the original file to the expected location
            source_path = Rails.root.join('test/fixtures/files/income_proof.pdf')
            FileUtils.cp(source_path, disk_path)

            fixed_files << :income_proof
          end
        end

        # Check residency proof
        if app.residency_proof.attached?
          blob = app.residency_proof.blob
          disk_key = blob.key
          disk_path = Rails.root.join('storage', disk_key[0, 2], disk_key[2, 2], disk_key)

          unless File.exist?(disk_path)
            seed_puts "  Fixing missing residency proof for Application ##{app.id}..."

            # Create directory structure if needed
            dir_path = Rails.root.join('storage', disk_key[0, 2], disk_key[2, 2])
            FileUtils.mkdir_p(dir_path)

            # Copy the original file to the expected location
            source_path = Rails.root.join('test/fixtures/files/residency_proof.pdf')
            FileUtils.cp(source_path, disk_path)

            fixed_files << :residency_proof
          end
        end

        # Check medical certification
        if app.medical_certification.attached?
          blob = app.medical_certification.blob
          disk_key = blob.key
          disk_path = Rails.root.join('storage', disk_key[0, 2], disk_key[2, 2], disk_key)

          unless File.exist?(disk_path)
            seed_puts "  Fixing missing medical certification for Application ##{app.id}..."

            # Create directory structure if needed
            dir_path = Rails.root.join('storage', disk_key[0, 2], disk_key[2, 2])
            FileUtils.mkdir_p(dir_path)

            # Copy the original file to the expected location
            source_path = Rails.root.join('test/fixtures/files/medical_certification_valid.pdf')
            FileUtils.cp(source_path, disk_path)

            fixed_files << :medical_certification
          end
        end

        # Report fixed files
        seed_success "  ✓ Fixed #{fixed_files.size} missing files for Application ##{app.id}: #{fixed_files.join(', ')}" if fixed_files.any?
      end
    end
  rescue StandardError => e
    seed_error "Seeding failed: #{e.message}"
    puts 'Backtrace:'
    e.backtrace.first(10).each { |line| puts line }
    exit 1
  else
    puts 'Seeding completed successfully!' unless Rails.env.production?
  end
end
