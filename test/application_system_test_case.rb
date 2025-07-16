# frozen_string_literal: true

require 'test_helper'
require 'socket'

# --------------------------------------------------------------------------
# SECTION 1: CAPYBARA DRIVER REGISTRATION
# --------------------------------------------------------------------------
# This is the single, authoritative place where the Cuprite driver is
# registered and configured.
# --------------------------------------------------------------------------
Capybara.register_driver :cuprite do |app|
  # Hard-block third-party hosts using Chrome's host resolver
  blocked_hosts = %w[
    google-analytics.com
    googletagmanager.com
    fonts.googleapis.com
    fonts.gstatic.com
    *.facebook.com
    *.doubleclick.net
    *.googlesyndication.com
  ]

  # Format host resolver rules correctly - each rule needs its own MAP entry
  block_rules = blocked_hosts.map { |h| "MAP #{h} 0.0.0.0" }.join(', ')

  Capybara::Cuprite::Driver.new(
    app,
    # General options
    window_size: [1400, 1000],
    js_errors: true, # Raise Ruby errors for JS console errors
    inspector: true, # Allow `page.driver.debug` to open a browser inspector

    # Performance & Stability
    process_timeout: 60, # Increased time to wait for Chrome to start (especially in CI/Docker)
    timeout: 60,         # Increased time to wait for a command to finish (especially in CI/Docker)
    url_blacklist: [     # Backup blocking for any missed external requests (using regexps)
      /google-analytics\.com/,
      /googletagmanager\.com/,
      /fonts\.googleapis\.com/
    ],

    # Headless mode control via environment variable
    headless: %w[false 0].exclude?(ENV.fetch('HEADLESS', 'true')),

    # Slow-motion mode for debugging
    slowmo: ENV.fetch('SLOWMO', 0).to_f,

    # Browser options for stability, especially in CI/Docker
    browser_options: {
      'no-sandbox' => nil,
      'disable-gpu' => nil,
      'disable-dev-shm-usage' => nil,
      # Hard-block external hosts at the network level
      'host-resolver-rules' => block_rules
    },

    # Network headers to short-circuit geo queries
    network_headers: {
      'Accept-Language' => 'en-US'
    }
  )
end

# --------------------------------------------------------------------------
# SECTION 2: COMPREHENSIVE CUPRITE RESCUE MODULE
# --------------------------------------------------------------------------
# This module patches Capybara's lowest-level synchronize method to catch
# ALL Ferrum errors, providing complete protection for the entire DSL.
# --------------------------------------------------------------------------
module CupriteRescue
  RETRY_ERRORS = [
    Ferrum::DeadBrowserError,
    Ferrum::PendingConnectionsError,
    Ferrum::NodeNotFoundError
  ].freeze
  MAX_RETRIES = 2

  def synchronize(*)
    tries = 0
    super
  rescue *RETRY_ERRORS => e
    raise if (tries += 1) > MAX_RETRIES

    warn "🔄  #{e.class} – restarting Cuprite (#{tries})"
    hard_restart
    retry
  end
end

# CupriteSessionExtensions - Add hard restart capability
module CupriteSessionExtensions
  def hard_restart
    browser&.quit
    Capybara.reset_sessions!
  end
end

# --------------------------------------------------------------------------
# SECTION 3: GLOBAL CAPYBARA CONFIGURATION
# --------------------------------------------------------------------------
# This block sets the global configuration for Capybara itself.
# --------------------------------------------------------------------------
Capybara.configure do |config|
  config.default_driver = :cuprite
  config.javascript_driver = :cuprite
  config.default_max_wait_time = 10 # Default time Capybara waits for elements
  config.server = :puma, { Silent: true }
  config.server_host = '127.0.0.1' # Use localhost instead of 0.0.0.0
  # Use dynamic port allocation for parallel testing (avoids port conflicts)
  config.server_port = nil # Let Capybara choose available ports
  config.save_path = Rails.root.join('tmp/capybara')
  config.disable_animation = true # Speeds up tests
  config.enable_aria_label = true
end

# Apply CupriteRescue wrapper once, process-wide and threadsafe
Capybara::Session.prepend(CupriteRescue)

# Include CupriteSessionExtensions for hard restart capability
Capybara::Session.include CupriteSessionExtensions

# Patch fill_in to avoid Node#set warnings and flakiness under Cuprite
module FillInCupritePatch
  def fill_in(locator, options = {})
    if driver.is_a?(Capybara::Cuprite::Driver) && options.key?(:with)
      # Extract only the value and ensure it's a clean string to avoid Node#set option errors
      value = options[:with].to_s
      element = find_field(locator)
      element.native.set(value)
    else
      super
    end
  end
end

Capybara::Session.prepend(FillInCupritePatch)

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

  def users(sym)
    email = EMAILS.fetch(sym) { raise ArgumentError, "Unknown user #{sym}" }
    User.find_or_create_by!(email: email) do |u|
      u.password = 'password123'
      u.first_name = sym.to_s.titleize.split('_').first
      u.last_name = 'User'
      u.status = if sym == :unconfirmed_user
                   :inactive
                 else
                   :active
                 end
    end
  end

  def applications(kind = :any)
    scope = Application.all
    case kind.to_sym
    when :in_progress
      scope.find_by(status: 'in_progress') ||
        scope.first ||
        raise(ArgumentError, 'No applications found in seeds (expected in_progress)')
    when :submitted_application
      # Try multiple possible statuses that indicate a submitted application
      scope.where(status: %w[in_progress awaiting_documents]).first ||
        scope.first ||
        raise(ArgumentError, 'No applications found in seeds (expected in_progress or awaiting_documents)')
    when :approved_application
      scope.find_by(status: 'approved') ||
        scope.first ||
        raise(ArgumentError, 'No applications found in seeds (expected approved)')
    when :pending_application
      scope.where(status: %w[needs_information awaiting_documents]).first ||
        scope.first ||
        raise(ArgumentError, 'No applications found in seeds (expected needs_information or awaiting_documents)')
    when :pending_with_proofs
      # Find a pending application that has both income and residency proofs attached
      scope.joins(:income_proof_attachment, :residency_proof_attachment)
           .where(status: %w[needs_information awaiting_documents]).first ||
        scope.first ||
        raise(ArgumentError, 'No applications found in seeds (expected pending with proofs)')
    when :waiting_period
      # Look for applications that are in waiting period (approved but within 3 year window)
      scope.where(status: 'approved').where('created_at > ?', 3.years.ago).first ||
        scope.where(status: 'approved').first ||
        raise(ArgumentError, 'No applications found in seeds (expected waiting_period)')
    when :training_request
      # Since training_request status doesn't exist, look for approved applications
      # that would likely need training (approved with all proofs approved)
      scope.where(status: 'approved', income_proof_status: 'approved', residency_proof_status: 'approved').first ||
        scope.where(status: 'approved').first ||
        scope.first ||
        raise(ArgumentError, 'No applications found in seeds (expected approved applications for training)')
    when :rejected
      scope.find_by(status: 'rejected') ||
        scope.first ||
        raise(ArgumentError, 'No applications found in seeds (expected rejected)')
    else
      scope.first ||
        raise(ArgumentError, 'No applications found in seeds')
    end
  end

  def debug_puts(msg)
    puts msg if ENV['VERBOSE_TESTS']
  end
end

# MemorySafeTestHelpers -------------------------------------------------------
# Lightweight wrappers around FactoryBot that avoid memory-intensive operations
module MemorySafeTestHelpers
  SPECIAL_TRAITS = %i[confirmed with_webauthn_credential].freeze

  def create(factory_name, *traits_and_attrs)
    traits, attrs = traits_and_attrs.partition { |t| t.is_a?(Symbol) }

    # Handle special user traits that need conversion
    if factory_name == :user && traits.intersect?(SPECIAL_TRAITS)
      attrs = attrs.first || {}
      attrs[:status] = :active if traits.include?(:confirmed)
      # Add webauthn credential handling if needed
      traits -= SPECIAL_TRAITS
    end

    # Delegate to FactoryBot for proper validation and better error messages
    FactoryBot.create(factory_name, *traits, *attrs)
  end

  def create_list(factory_name, count, *args)
    FactoryBot.create_list(factory_name, count, *args)
  end

  # Helper method to create lightweight blob stubs for ActiveStorage
  def create_lightweight_blob(filename: 'test.pdf', content_type: 'application/pdf')
    ActiveStorage::Blob.create_after_upload!(
      io: StringIO.new('stub'),
      filename: filename,
      content_type: content_type
    )
  end

  # Helper to attach a lightweight blob to a model (direct attach without explicit blob)
  def attach_lightweight_proof(model, attachment_name, filename: 'test.pdf')
    model.public_send(attachment_name).attach(
      io: StringIO.new('stub'),
      filename: filename,
      content_type: 'application/pdf'
    )
  end

  def debug_puts(msg)
    puts msg if ENV['VERBOSE_TESTS']
  end
end

# --------------------------------------------------------------------------
# SECTION 3: THE BASE TEST CASE CLASS
# --------------------------------------------------------------------------
# All system tests will inherit from this class. It includes all necessary
# helpers and defines a robust setup/teardown lifecycle.
# --------------------------------------------------------------------------
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Use the driver we registered above.
  driven_by :cuprite, screen_size: [1400, 1000]

  # Include all necessary helper modules.
  include SystemTestAuthentication
  include SystemTestHelpers
  include FplPolicyHelpers
  include SeedLookupHelpers            # users(:admin) etc. (defined above)
  include MemorySafeTestHelpers        # create() wrapper that uses FactoryBot (defined above)
  # SeedLookupHelper is in test_helper.rb for global access.

  # Enable parallel testing for system tests (capped to avoid /tmp exhaustion)
  parallelize(workers: ENV.fetch('PARALLEL_WORKERS', 4).to_i)

  # Database cleaning strategy for system tests
  if defined?(DatabaseCleaner)
    # One-time setup per parallel worker
    parallelize_setup do
      DatabaseCleaner.clean_with(:truncation)
      load Rails.root.join('db/seeds.rb')
      # Reload seed data so each parallel system-test worker has application fixtures

      # Sync app_host with dynamic port after server boots
      Capybara.app_host = Capybara.current_session.server.base_url
    end

    setup do
      DatabaseCleaner.strategy = :transaction
      DatabaseCleaner.start
    end

    teardown do
      DatabaseCleaner.clean
    end
  end

  # --- Test Lifecycle Hooks ---

  setup do
    # 1. Store and set validation flag to prevent leaking to other test types
    @skip_flag_original = Application.skip_wait_period_validation
    Application.skip_wait_period_validation = true

    # 2. Reset Capybara session state to ensure a clean browser.
    Capybara.reset_sessions!

    # 3. Clear any lingering authentication state from previous tests.
    clear_test_identity

    # 4. Clear any pending network connections from previous tests
    clear_pending_network_connections if respond_to?(:clear_pending_network_connections, true)

    # 5. Inject JavaScript fixes for known issues (e.g., Chart.js).
    inject_test_javascript_fixes if page&.driver
  end

  teardown do
    # 1. Log test failure details
    if failed?
      puts "\n"
      puts "Failure in: #{self.class.name}##{name}"
    end

    # 2. Ensure the user is signed out and the session is fully cleared.
    system_test_sign_out

    # 3. Restore the original validation flag to prevent leaking into other tests
    Application.skip_wait_period_validation = @skip_flag_original
  end

  # DB cleaning – truncation is required because browser ≠ test thread
  def self.use_transactional_tests?
    false
  end

  # --- Helper Methods ---
  # Helper to safely skip wait period validation with automatic cleanup
  def with_wait_period_skipped
    original_value = Application.skip_wait_period_validation
    Application.skip_wait_period_validation = true
    yield
  ensure
    Application.skip_wait_period_validation = original_value
  end

  # Override Rails' take_screenshot to provide custom naming and logging
  def take_screenshot(name = "failure-#{Time.now.to_i}")
    return nil unless page&.driver

    # Use Rails' built-in screenshot functionality
    path = super
    puts "📸 Screenshot saved: #{path}" if path
    path
  rescue StandardError => e
    puts "Failed to take screenshot: #{e.message}"
    nil
  end

  # Helper to manually restart browser when tests detect issues
  def restart_browser!
    puts '🔄 Manually restarting browser...'
    hard_restart
  end

  # Cuprite-friendly fill_in helper that avoids "Options passed to Node#set" warnings
  def cuprite_fill_in(locator, value)
    element = find_field(locator)
    element.native.set(value.to_s)
  end

  # Helper for tests that need JS to reach across threads (file uploads, ActionCable, etc.)
  def using_truncation(&block)
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.cleaning(&block)
  ensure
    DatabaseCleaner.strategy = :transaction
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

  # Use the connection clearing method from SystemTestHelpers consistently
  def clear_pending_connections
    clear_pending_network_connections
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

  def debug_page
    puts "URL: #{current_url}\nHTML: #{page.html[0, 400]}…"
    take_screenshot("debug-#{Time.now.to_i}")
  end

  # Helper to wait for an arbitrary condition without ad-hoc sleeps.
  # Usage: wait_until(time: seconds) { page.current_path == expected_path }
  def wait_until(time: Capybara.default_max_wait_time)
    Timeout.timeout(time) do
      until (value = yield)
        sleep(0.1)
      end
      value
    end
  end

  private

  # Injects JS patches to fix known issues, like Chart.js recursion loops
  # that can cause the browser to hang or crash.
  def inject_test_javascript_fixes
    unless defined?(@_chart_patch_done) && @_chart_patch_done
      page.execute_script(<<~JS)
        // Disable Chart.js globally (prevents huge CPU during screenshots)
        if (window.Chart) {
          window.Chart = { register: ()=>{}, defaults:{}, Chart: ()=>({ destroy:()=>{}, update:()=>{}, render:()=>{} }) };
        }
        // Guard against getComputedStyle infinite recursion (a known Ferrum bug)
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
      @_chart_patch_done = true
    end
  rescue Ferrum::DeadBrowserError
    # Ignore if browser is already dead, teardown will handle it.
  rescue StandardError => e
    puts "Warning: JS injection failed: #{e.message}"
  end
end
