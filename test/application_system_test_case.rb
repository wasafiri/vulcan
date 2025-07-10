# frozen_string_literal: true

require 'test_helper'

# Helper Modules – defined before use

# SeedLookupHelpers -----------------------------------------------------------
module SeedLookupHelpers
  EMAILS = {
    admin: 'admin@example.com',
    admin_david: 'admin@example.com',
    confirmed_user: 'user@example.com',
    confirmed_user2: 'user2@example.com',
    unconfirmed_user: 'unconfirmed@example.com',
    trainer: 'trainer@example.com',
    evaluator: 'evaluator@example.com',
    medical_provider: 'medical@example.com',
    constituent_john: 'john.doe@example.com',
    constituent_jane: 'jane.doe@example.com',
    constituent_alex: 'alex.smith@example.com',
    constituent_rex: 'rex.canine@example.com',
    vendor_raz: 'raz@testemail.com',
    vendor_teltex: 'teltex@testemail.com',
    constituent_alice: 'alice.doe@example.com'
  }.freeze

  def users(key)
    key = key.to_sym
    @users_cache ||= {}
    @users_cache[key] ||= begin
      email = EMAILS[key]
      debug_puts "Unknown user fixture '#{key}'" unless email
      User.find_by(email: email)
    end
  end

  def applications(key)
    case key.to_sym
    when :submitted_application then Application.where(status: %w[submitted in_progress]).first
    when :approved_application  then Application.find_by(status: 'approved')
    when :pending_application   then Application.find_by(status: 'pending')
    else Application.first
    end
  end

  def print_queue_items(key)
    @print_queue_items_cache ||= {}
    @print_queue_items_cache[key] ||= build_print_queue_item(key.to_sym)
  end

  private

  def build_print_queue_item(key)
    case key
    when :pending_letter_1
      letter_item(key, 'application_approved', users(:confirmed_user), 1.day.ago)
    when :pending_letter_2
      letter_item(key, 'income_proof_rejected', users(:confirmed_user2), 2.days.ago)
    else
      PrintQueueItem.first
    end
  end

  def letter_item(key, type, constituent, timestamp)
    # Create a minimal valid PDF content instead of just text
    pdf_content = "%PDF-1.4\n1 0 obj\n<<\n/Type /Catalog\n/Pages 2 0 R\n>>\nendobj\n2 0 obj\n<<\n/Type /Pages\n/Kids [3 0 R]\n/Count 1\n>>\nendobj\n3 0 obj\n<<\n/Type /Page\n/Parent 2 0 R\n/MediaBox [0 0 612 792]\n>>\nendobj\nxref\n0 4\n0000000000 65535 f \n0000000010 00000 n \n0000000053 00000 n \n0000000125 00000 n \ntrailer\n<<\n/Size 4\n/Root 1 0 R\n>>\nstartxref\n174\n%%EOF"

    item = PrintQueueItem.new(
      letter_type: type,
      status: 'pending',
      constituent: constituent,
      created_at: timestamp,
      updated_at: timestamp
    )

    # Attach the PDF BEFORE saving so presence validation passes
    item.pdf_letter.attach(
      io: StringIO.new(pdf_content),
      filename: "#{key}.pdf",
      content_type: 'application/pdf'
    )

    item.save!
    item
  end

  def debug_puts(msg)
    puts msg if ENV['VERBOSE_TESTS']
  end
end

# FactoryAdapter --------------------------------------------------------------
module FactoryAdapter
  def create(factory_name, *args)
    traits, attrs = args.partition { |a| a.is_a? Symbol }
    # The factory adapter filters and merges attributes safely
    # Arrays and non-Hash objects are filtered out to prevent merge errors
    attrs = attrs.each_with_object({}) { |a, memo| memo.merge!(a) if a.is_a?(Hash) }

    case factory_name
    when :admin                            then users(:admin)
    when :constituent, :user               then resolve_user_factory(traits, attrs)
    when :vendor, :vendor_user             then traits.include?(:approved) ? users(:vendor_raz) : users(:vendor_teltex)
    when :application                      then build_application(traits, attrs)
    when :invoice                          then Invoice.first
    else delegate_to_factory_bot(factory_name, args)
    end
  end

  def create_list(factory_name, count, *)
    args = Array(*)
    Array.new(count) { create(factory_name, *args) }
  end

  private

  def resolve_user_factory(traits, attrs)
    return users(:evaluator)        if traits.include?(:evaluator)
    return users(:medical_provider) if traits.include?(:medical_provider)
    return users(:trainer)          if traits.include?(:trainer)

    # Check for email in attrs and create a new user if provided
    if attrs[:email] || attrs['email']
      email = attrs[:email] || attrs['email']
      existing_user = User.find_by(email: email)
      return existing_user if existing_user

      # Create a new constituent with the provided attributes
      Users::Constituent.create!(attrs.merge(
                                   password: 'password123',
                                   first_name: attrs[:first_name] || 'Test',
                                   last_name: attrs[:last_name] || 'User',
                                   date_of_birth: attrs[:date_of_birth] || 30.years.ago,
                                   hearing_disability: true
                                 ))
    else
      users(:confirmed_user)
    end
  end

  def build_application(traits, attrs)
    return Application.first if traits.empty? && attrs.empty?

    # Ensure skip validation flag is set for this thread
    Application.skip_wait_period_validation = true

    user = attrs.delete(:user) || create_unique_user_for_application

    # Filter out transient attributes that don't belong on the Application model
    transient_attrs = %w[skip_proofs use_mock_attachments]
    filtered_attrs = attrs.reject { |key, _| transient_attrs.include?(key.to_s) }

    # Set application_date to avoid waiting period validation for test applications
    # This mimics the :old_enough_for_new_application trait behavior
    base_attrs = default_app_attrs(traits).merge(filtered_attrs).merge(user: user)
    base_attrs[:application_date] = 4.years.ago unless base_attrs.key?(:application_date)

    application = Application.create!(base_attrs)

    # Handle special traits that need file attachments
    # This replicates the after(:create) hooks from the factory traits
    if traits.include?(:in_progress_with_rejected_proofs)
      attach_proof_files_for_rejected_proofs(application)
    elsif traits.include?(:in_progress_with_pending_proofs)
      attach_proof_files_for_pending_proofs(application)
    end

    application
  rescue ActiveRecord::RecordInvalid => e
    raise "Neutered Exception #{e.class}: #{e.message}" if e.message.include?('You must wait 3 years')

    raise
  end

  def create_unique_user_for_application
    # Create a unique constituent for each application to avoid 3-year validation
    timestamp = Time.now.to_i
    random_suffix = rand(10_000)
    email = "system_test_user_#{timestamp}_#{random_suffix}@example.com"
    phone = "555-#{format('%03d', rand(1000))}-#{format('%04d', rand(10_000))}"

    Users::Constituent.create!(
      email: email,
      password: 'password123',
      first_name: 'Test',
      last_name: 'User',
      date_of_birth: 30.years.ago,
      phone: phone,
      hearing_disability: true
    )
  end

  def default_app_attrs(traits)
    base = {
      maryland_resident: true,
      self_certify_disability: true,
      medical_provider_name: 'Test Provider',
      medical_provider_phone: '555-123-4567',
      medical_provider_email: 'provider@example.com',
      household_size: 2,
      annual_income: 30_000,
      status: 'in_progress'
    }

    if traits.include?(:draft)
      base.merge(status: 'draft')
    elsif traits.include?(:approved)
      base.merge(status: 'approved', medical_certification_status: 'approved')
    elsif traits.include?(:in_progress_with_rejected_proofs)
      base.merge(income_proof_status: 'rejected', residency_proof_status: 'rejected')
    elsif traits.include?(:in_progress_with_pending_proofs)
      base.merge(income_proof_status: 'not_reviewed', residency_proof_status: 'not_reviewed')
    else
      base
    end
  end

  def delegate_to_factory_bot(factory_name, args)
    return FactoryBot.create(factory_name, *args) if defined?(FactoryBot)

    debug_puts "FactoryBot unavailable for #{factory_name}"
    nil
  rescue StandardError => e
    debug_puts "FactoryBot create failed: #{e.class}: #{e.message}"
    nil
  end

  def debug_puts(msg)
    puts msg if ENV['VERBOSE_TESTS']
  end

  # Helper methods to attach proof files for specific traits
  # These replicate the after(:create) hooks from the factory traits
  def attach_proof_files_for_rejected_proofs(application)
    # Attach sample proofs to represent the uploaded-then-rejected scenario
    application.income_proof.attach(
      io: Rails.root.join('test/fixtures/files/medical_certification_valid.pdf').open,
      filename: 'income_proof.pdf',
      content_type: 'application/pdf'
    )
    application.residency_proof.attach(
      io: Rails.root.join('test/fixtures/files/medical_certification_valid.pdf').open,
      filename: 'residency_proof.pdf',
      content_type: 'application/pdf'
    )
  rescue StandardError => e
    debug_puts "Failed to attach rejected proof files: #{e.message}"
    raise
  end

  def attach_proof_files_for_pending_proofs(application)
    # Attach proofs that need review
    application.income_proof.attach(
      io: Rails.root.join('test/fixtures/files/medical_certification_valid.pdf').open,
      filename: 'income_proof.pdf',
      content_type: 'application/pdf'
    )
    application.residency_proof.attach(
      io: Rails.root.join('test/fixtures/files/medical_certification_valid.pdf').open,
      filename: 'residency_proof.pdf',
      content_type: 'application/pdf'
    )
  rescue StandardError => e
    debug_puts "Failed to attach pending proof files: #{e.message}"
    raise
  end
end

# ApplicationSystemTestCase --------------------------------------------------
# Central hub for *all* browser‑driven system tests.
#
# ▸ Keeps infrastructure (driver, DB strategy, life‑cycle) in this file.
# ▸ Everything domain‑specific lives in tiny mix‑ins to keep the class tidy.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Browser -----------------------------------------------------------------
  CUCRITE_OPTIONS = {
    js_errors: ENV.fetch('JS_ERRORS', 'false') == 'true',
    slowmo: ENV.fetch('SLOWMO', 0).to_f,
    process_timeout: 45,
    timeout: 25,
    window_size: [1400, 1400],
    headless: ENV.fetch('HEADLESS', 'true') != 'false',

    # Chrome stability flags – *do not remove* unless you know what breaks
    browser_options: {
      'no-sandbox' => nil,
      'disable-gpu' => nil,
      'disable-dev-shm-usage' => nil,
      'disable-web-security' => nil,
      'disable-features' => 'VizDisplayCompositor',
      'disable-ipc-flooding-protection' => nil,
      'disable-backgrounding-occluded-windows' => nil,
      'disable-background-timer-throttling' => nil,
      'disable-renderer-backgrounding' => nil,
      'disable-domain-reliability' => nil,
      'disable-breakpad' => nil,
      'disable-sync' => nil,
      'disable-popup-blocking' => nil,
      'metrics-recording-only' => nil,
      'no-first-run' => nil,
      'no-default-browser-check' => nil,
      'disable-blink-features' => 'AutomationControlled',
      'memory-pressure-off' => nil,
      'max_old_space_size' => '2048'
    },

    # Block noisy external requests
    url_blacklist: [
      %r{\Ahttps://www\.google-analytics\.com/},
      %r{\Ahttps://googletagmanager\.com/},
      %r{\Ahttps://fonts\.googleapis\.com/},
      %r{\Ahttps://fonts\.gstatic\.com/}
    ],

    page_options: {
      'enable-automation' => true,
      'disable-web-security' => true,
      'disable-features' => 'VizDisplayCompositor'
    }
  }.freeze

  Capybara.register_driver(:cuprite_rails) do |app|
    Capybara::Cuprite::Driver.new(app, **CUCRITE_OPTIONS)
  end

  driven_by :cuprite_rails, using: :chrome, screen_size: [1400, 1400]

  # Routing helpers ---------------------------------------------------------
  include Rails.application.routes.url_helpers
  Rails.application.routes.default_url_options[:host] = 'www.example.com'

  # Domain‑level helpers – mix‑ins only, no logic here ----------------------
  include SystemTestAuthentication     # sign‑in helpers
  include SystemTestHelpers            # scrolling / safe_click etc.
  include FplPolicyHelpers             # setup_fpl_policies
  include SeedLookupHelpers            # users(:admin) etc. (now defined above)
  include FactoryAdapter               # create(:application) wrapper (now defined above)

  # Test life‑cycle ---------------------------------------------------------
  setup do
    Capybara.default_max_wait_time = extended_wait_required? ? 8 : 3

    # System tests need to bypass the waiting period validation for test data creation
    Application.skip_wait_period_validation = true

    Capybara.reset_sessions!
    clear_pending_connections_fast # must run *before* any page nav
    ensure_test_data_available
    setup_fpl_policies if respond_to?(:setup_fpl_policies)
    setup_paper_application_context if respond_to?(:setup_paper_application_context)
    clear_test_identity if respond_to?(:clear_test_identity)
    inject_test_javascript_fixes if page&.driver
  end

  teardown do
    system_test_sign_out if respond_to?(:system_test_sign_out)
    clear_pending_connections_fast
    Capybara.reset_sessions!
    clear_test_identity if respond_to?(:clear_test_identity)
    teardown_paper_application_context if respond_to?(:teardown_paper_application_context)
  end

  # DB cleaning – truncation is required because browser ≠ test thread
  def self.use_transactional_tests?
    false
  end

  # High‑level helpers ---------------------------------------------------------

  # Wait for DOM ready plus network quiet and sweep stray connections afterwards
  def wait_for_page_load(timeout: 5)
    page.has_selector?('body', wait: timeout)
    clear_pending_connections_fast
  end

  # Robust Turbo wait with Ferrum edge‑case handling
  def wait_for_turbo(timeout: 3)
    page.has_no_selector?('.turbo-progress-bar', wait: timeout)
  rescue Capybara::ElementNotFound
    # progress bar never appeared – likely a fast nav
  rescue Ferrum::NodeNotFoundError
    sleep 0.1 # element disappeared mid‑query – retry once
    retry
  ensure
    clear_pending_connections_fast
  end

  # Auth assertion helpers – many tests rely on these
  def assert_authenticated_as(user, msg = nil)
    assert_no_match(/Sign (In|Up)/i, page.text, msg || 'Found sign‑in link for authenticated user')
    assert_includes page.text, 'Sign Out', msg || 'Missing sign‑out link'
    assert_not_equal sign_in_path, current_path, msg || 'Still on sign‑in page'
    return unless user.respond_to?(:first_name) && user.first_name.present?

    assert_match(/#{Regexp.escape(user.first_name)}/, page.text, msg || 'User name missing from UI')
  end

  def assert_not_authenticated(msg = nil)
    assert_match(/Sign (In|Up)/i, page.text, msg || 'Missing sign‑in link when logged‑out')
    assert_not_includes page.text, 'Sign Out', msg || 'Sign‑out link present when logged‑out'
  end

  def with_authenticated_user(user)
    system_test_sign_in(user)
    yield if block_given?
  ensure
    system_test_sign_out
  end

  # Sign in method that doesn't require a block and doesn't automatically sign out
  # This is for tests that manage their own authentication lifecycle
  def sign_in(user)
    system_test_sign_in(user)
  end

  # Misc utilities kept for backwards compatibility ------------------------------------
  def toggle_password_visibility(field_id)
    field  = find("input##{field_id}")
    button = field.sibling('button[aria-label]')
    page.execute_script('arguments[0].click()', button)
  end

  def fixture_file_upload(rel_path, mime_type = nil)
    Rack::Test::UploadedFile.new(Rails.root.join(rel_path), mime_type || Mime[:pdf].to_s)
  end

  def take_screenshot(name = nil)
    name ||= "screenshot-#{Time.current.strftime('%Y%m%d%H%M%S')}"
    path = Rails.root.join("tmp/screenshots/#{name}.png")
    FileUtils.mkdir_p(path.dirname)
    page.save_screenshot(path.to_s) # rubocop:disable Lint/Debugger
    puts "Screenshot saved to #{path}" if ENV['VERBOSE_TESTS']
    path
  rescue StandardError => e
    debug_puts "Screenshot failed: #{e.message}"
    nil
  end

  def debug_page
    puts "URL: #{current_url}\nHTML: #{page.html[0, 400]}…"
    take_screenshot("debug-#{Time.now.to_i}")
  end

  private

  # If we need longer waits for heavy email template rendering tests
  def extended_wait_required?
    self.class.name.include?('EmailTemplatesTest')
  end

  # Aggressively clear Cuprite's CDP network cache; extra steps for email tests
  def clear_pending_connections_fast
    return unless page&.driver.is_a?(Capybara::Cuprite::Driver)

    browser = page.driver.browser
    browser.network.clear_cache
    browser.runtime.run_if_waiting_for_debugger

    if extended_wait_required?
      browser.runtime.evaluate('window.stop && window.stop()')
      sleep 0.1
    end
  rescue StandardError => e
    debug_puts "Connection clear failed: #{e.message}"
  end

  # Inject JS patches that stop Chart.js + getComputedStyle recursion loops
  def inject_test_javascript_fixes
    page.execute_script <<~JS
      // Disable Chart.js globally (prevents huge CPU during screenshots)
      if (window.Chart) {
        window.Chart = { register: ()=>{}, defaults:{}, Chart: ()=>({ destroy:()=>{}, update:()=>{}, render:()=>{} }) };
      }
      // Guard against getComputedStyle infinite recursion (Ferrum bug)
      if (!window._getComputedStylePatched) {
        const original = window.getComputedStyle;
        let depth = 0;
        window.getComputedStyle = function(el, pseudo) {
          if (depth > 50) { console.warn('getComputedStyle recursion avoided'); return {}; }
          depth++; const result = original.call(this, el, pseudo); depth--; return result;
        };
        window._getComputedStylePatched = true;
      }
    JS
  rescue StandardError => e
    debug_puts "JS injection failed: #{e.message}"
  end

  def ensure_test_data_available
    return if User.exists?(email: 'admin@example.com')

    debug_puts 'Seed data missing – run `RAILS_ENV=test rails db:seed`'
  end

  def debug_puts(msg)
    puts msg if ENV['VERBOSE_TESTS'] || ENV['DEBUG_AUTH']
  end
end
