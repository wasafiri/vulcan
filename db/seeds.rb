# frozen_string_literal: true

require 'factory_bot_rails'
require 'yaml'
require 'active_record/fixtures'

# Helper method to conditionally output messages
def seed_puts(message)
  Rails.logger.debug message if ENV['VERBOSE_TESTS'] || Rails.env.development?
end

# Helper method for error messages (always shown)
def seed_error(message)
  Rails.logger.debug { "[SEED ERROR] #{message}" }
end

# Helper method for success messages (only in verbose mode)
def seed_success(message)
  Rails.logger.debug message if ENV['VERBOSE_TESTS']
end

# Helper method to attach proof documents to applications
def attach_proof_to_application(app, proof_config)
  proof_type = proof_config[:type]
  status_method = proof_config[:status_method]
  attachment_method = proof_config[:attachment_method]
  file_path = proof_config[:file_path]
  filename = proof_config[:filename]
  indent = proof_config[:indent] || '    '

  status_value = app.send(status_method)
  attachment = app.send(attachment_method)

  return unless valid_proof_status?(proof_type, status_value) && !attachment.attached?

  attach_proof_file(app, attachment, proof_type, file_path, filename, indent)
end

def valid_proof_status?(proof_type, status_value)
  valid_statuses = case proof_type
                   when :income_proof, :residency_proof
                     %w[approved rejected]
                   when :medical_certification
                     %w[received accepted]
                   else
                     []
                   end
  status_value.to_s.in?(valid_statuses)
end

def attach_proof_file(app, attachment, proof_type, file_path, filename, indent)
  seed_puts "#{indent}Attaching #{proof_type.to_s.humanize.downcase}..."
  full_file_path = Rails.root.join('test/fixtures/files', file_path)

  if File.exist?(full_file_path)
    attachment.attach(
      io: File.open(full_file_path),
      filename: filename,
      content_type: 'application/pdf'
    )
    app.save
    seed_success "#{indent}✓ #{proof_type.to_s.humanize} attached"
  else
    seed_error "#{proof_type.to_s.humanize} file not found at #{full_file_path}"
  end
end

# Helper method to verify and fix missing attachment files
def verify_and_fix_attachment(app, attachment_method, proof_type, source_filename, fixed_files)
  attachment = app.send(attachment_method)

  return unless attachment.attached?

  blob = attachment.blob
  disk_key = blob.key
  disk_path = Rails.root.join('storage', disk_key[0, 2], disk_key[2, 2], disk_key)

  return if File.exist?(disk_path)

  seed_puts "  Fixing missing #{proof_type.to_s.humanize.downcase} for Application ##{app.id}..."

  # Create directory structure if needed
  dir_path = Rails.root.join('storage', disk_key[0, 2], disk_key[2, 2])
  FileUtils.mkdir_p(dir_path)

  # Copy the original file to the expected location
  source_path = Rails.root.join('test/fixtures/files', source_filename)
  FileUtils.cp(source_path, disk_path)

  fixed_files << proof_type
end

# Main seeding methods

def clear_existing_data
  seed_puts 'Clearing existing data...'

  # Clear Session records first to avoid foreign key constraint violations
  seed_puts '  Clearing Session records...'
  Session.in_batches(of: 100).delete_all

  # Define the order of deletion to respect foreign key constraints.
  # Models with foreign keys (e.g., W9Review) must be cleared before the models
  # they point to (e.g., User).

  # Clear models with dependencies first. User is cleared last.
  [W9Review, Invoice, ApplicationStatusChange, Evaluation, ProofReview,
   Notification, RoleCapability, PolicyChange, EmailTemplate, Product, Event, Policy, Application].each do |model|
    seed_puts "  Clearing #{model.name} records..."
    # Delete records in small batches to avoid memory issues
    model.in_batches(of: 100).delete_all
  end

  # Finally, clear the User model after all dependent records are gone.
  seed_puts '  Clearing User records...'
  User.in_batches(of: 100).delete_all
end

def create_products_from_fixtures
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
end

def create_policies
  seed_puts 'Creating policies...'
  # IMPORTANT: All policy keys used in the application MUST be defined here
  # If a policy is missing from this list, Policy.get('key') will return nil
  # This causes unexpected behavior in mailboxes, controllers, and other logic
  # Common missing policies that cause test failures:
  # - max_proof_rejections (used by ProofSubmissionMailbox)
  # - proof_submission_rate_limit_* (used by rate limiting)
  # - support_email (NOTE: Cannot be stored here - integers only!)
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
    'max_proof_rejections' => 3,
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
    raise "Policy #{key} ID not generated" if policy.id.blank?
    raise "Policy #{key} has wrong value" unless policy.value == value
  end
end

def load_fixtures_data
  seed_puts 'Loading fixtures in order...'
  fixtures_path = Rails.root.join('test/fixtures')
  users_map = load_users_fixture(fixtures_path)
  load_applications_fixture(fixtures_path, users_map)
  load_invoices_fixture(fixtures_path, users_map)
end

def load_users_fixture(fixtures_path)
  seed_puts 'Loading users fixture via ActiveRecord models...'
  user_fixture_file = fixtures_path.join('users.yml')
  users_map = {}

  if File.exist?(user_fixture_file)
    # Disable uniqueness validation on plaintext email column for seeding
    User._validators[:email].reject! { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }
    user_data = YAML.safe_load(ERB.new(File.read(user_fixture_file)).result, permitted_classes: [Date, DateTime, Time])
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
  users_map
end

def load_applications_fixture(fixtures_path, users_map)
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
end

def load_invoices_fixture(fixtures_path, users_map)
  # Disable invoice payment notifications during seeding
  Invoice.skip_callback(:save, :after, :send_payment_notification)
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
end

def seed_email_templates
  seed_puts 'Seeding email templates...'
  load Rails.root.join('db/seeds/email_templates.rb')

  # Ensure the registration confirmation template exists, as it's critical for sign-up.
  # This is a common source of errors if the main email_templates.rb seed file is missed or incomplete.
  # NOTE: Ideally, this would be in `db/seeds/email_templates.rb`, but adding it here for robustness.

  reg_confirm_name = 'application_notifications_registration_confirmation'

  EmailTemplate.find_or_create_by!(name: reg_confirm_name, format: :text) do |template|
    template.subject = 'Welcome to Maryland Accessible Telecommunications!'
    template.body = "Hello %{user_full_name},\n\nWelcome! Your account has been created successfully.\n\nThank you for joining."
    template.description = 'Sent to a new user upon successful registration.'
    template.variables = %w[user_full_name]
  end
end

def ensure_storage_directory
  seed_puts 'Ensuring storage directory exists...'
  storage_dir = Rails.root.join('storage')
  FileUtils.mkdir_p(storage_dir) unless storage_dir
end

def attach_files_to_applications
  seed_puts 'Attaching files to applications...'
  process_rex_canine_application
  process_other_applications
end

def process_rex_canine_application
  seed_puts 'Processing Rex Canine application specifically...'
  rex_app = Application.joins(:user).where(users: { first_name: 'Rex', last_name: 'Canine' }).first

  if rex_app
    seed_puts "Found Rex's application ##{rex_app.id}"
    seed_puts "  Current status - Income: #{rex_app.income_proof_status}, Residency: #{rex_app.residency_proof_status}"
    seed_puts "  Initial state - Income attached: #{rex_app.income_proof.attached?}, Residency attached: #{rex_app.residency_proof.attached?}"

    # For Rex's application, handle each proof separately
    attach_rex_income_proof(rex_app)
    attach_rex_residency_proof(rex_app)
  else
    seed_error 'Could not find Rex Canine application'
  end
  rex_app
end

def attach_rex_income_proof(rex_app)
  return unless rex_app.income_proof_status == 'approved' && !rex_app.income_proof.attached?

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

def attach_rex_residency_proof(rex_app)
  return unless rex_app.residency_proof_status.in?(%w[approved rejected]) && !rex_app.residency_proof.attached?

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

def process_other_applications
  rex_app = Application.joins(:user).where(users: { first_name: 'Rex', last_name: 'Canine' }).first

  Application.find_each do |app|
    # Skip Rex since we already processed it
    next if rex_app && app.id == rex_app.id

    # Skip applications with missing users
    if app.user.nil?
      seed_error "Skipping Application ##{app.id} - Missing user reference"
      next
    end

    seed_puts "  Processing Application ##{app.id} (#{app.user.email})"

    # Use helper method to attach each proof type
    attach_proof_to_application(app, {
                                  type: :income_proof,
                                  status_method: :income_proof_status,
                                  attachment_method: :income_proof,
                                  file_path: 'income_proof.pdf',
                                  filename: 'income_proof.pdf'
                                })
    attach_proof_to_application(app, {
                                  type: :residency_proof,
                                  status_method: :residency_proof_status,
                                  attachment_method: :residency_proof,
                                  file_path: 'residency_proof.pdf',
                                  filename: 'residency_proof.pdf'
                                })
    attach_proof_to_application(app, {
                                  type: :medical_certification,
                                  status_method: :medical_certification_status,
                                  attachment_method: :medical_certification,
                                  file_path: 'medical_certification_valid.pdf',
                                  filename: 'medical_certification_valid.pdf'
                                })
  end
end

def verify_and_fix_missing_files
  seed_puts 'Verifying all application attachments...'

  Application.find_each do |app|
    fixed_files = []

    # Verify and fix each proof type using helper method
    verify_and_fix_attachment(app, :income_proof, :income_proof, 'income_proof.pdf', fixed_files)
    verify_and_fix_attachment(app, :residency_proof, :residency_proof, 'residency_proof.pdf', fixed_files)
    verify_and_fix_attachment(app, :medical_certification, :medical_certification, 'medical_certification_valid.pdf', fixed_files)

    # Report fixed files
    seed_success "  ✓ Fixed #{fixed_files.size} missing files for Application ##{app.id}: #{fixed_files.join(', ')}" if fixed_files.any?
  end
end

# Main execution block
if Rails.env.production?
  Rails.logger.debug 'Production environment detected. Seeding skipped to prevent data override.'
else
  puts "🌱 SEEDING STARTED at #{Time.current}"
  begin
    ActiveRecord::Base.transaction do
      puts '🧹 Clearing existing data...'
      clear_existing_data

      puts '📦 Creating products from fixtures...'
      create_products_from_fixtures

      puts '📋 Creating policies...'
      create_policies

      puts '👥 Loading fixture data (users, applications, invoices)...'
      load_fixtures_data

      puts '📧 Seeding email templates...'
      seed_email_templates

      puts '📁 Ensuring storage directory exists...'
      ensure_storage_directory

      puts '📎 Attaching files to applications...'
      attach_files_to_applications

      puts '🔍 Verifying and fixing missing files...'
      verify_and_fix_missing_files
    end
  rescue StandardError => e
    puts "❌ SEEDING FAILED: #{e.message}"
    seed_error "Seeding failed: #{e.message}"
    Rails.logger.debug 'Backtrace:'
    e.backtrace.first(10).each { |line| Rails.logger.debug line }
    exit 1
  else
    # Show summary of what was created
    puts '📊 SEEDING SUMMARY:'
    puts "   Users: #{User.count}"
    puts "   Applications: #{Application.count}"
    puts "   Products: #{Product.count}"
    puts "   Policies: #{Policy.count}"
    puts "   Email Templates: #{EmailTemplate.count}"
    puts "   Invoices: #{Invoice.count}"
    puts "✅ SEEDING COMPLETED SUCCESSFULLY at #{Time.current}!"
    Rails.logger.debug 'Seeding completed successfully!' unless Rails.env.production?
  end
end
