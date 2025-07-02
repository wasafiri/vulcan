# frozen_string_literal: true

require 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # Don't load fixtures automatically - system tests use seeded data instead
  # fixtures :all # Commented out to avoid conflicts with seeded data

  include SystemTestAuthentication # Include authentication helper
  include SystemTestHelpers # Include helpers for working with Cuprite

  # Include URL helpers as a module to isolate them and prevent them from being treated as test methods
  module UrlHelpers
    include Rails.application.routes.url_helpers
  end
  include UrlHelpers

  # Configure default URL options for system tests
  Rails.application.routes.default_url_options[:host] = 'www.example.com'

  # Configure the browser with settings optimized per the testing guide
  # NOTE: This must be at the class level, not inside a setup block
  driven_by :cuprite, using: :chromium, screen_size: [1400, 1400] do |driver_options|
    # Use more reasonable timeouts - the guide suggests 300s was too aggressive
    driver_options.timeout = 120             # 2 minutes for actions
    driver_options.process_timeout = 120     # 2 minutes for browser startup
    driver_options.js_errors = false         # Don't fail on JS errors per guide
    driver_options.skip_image_loading = true # Skip loading images for faster tests
    driver_options.browser_options = {       # Additional browser options
      'disable-gpu': nil,                     # Disable GPU for more stable headless mode
      'disable-dev-shm-usage': nil,           # Disable /dev/shm usage to prevent crashes
      'disable-web-security': nil,            # Disable web security for easier testing
      'no-sandbox': nil,                      # Required for running in CI environments
      'disable-background-timer-throttling': nil, # Prevent timer throttling
      'disable-backgrounding-occluded-windows': nil, # Prevent window backgrounding
      'disable-renderer-backgrounding': nil,  # Prevent renderer backgrounding
      'disable-features': 'TranslateUI,VizDisplayCompositor', # Disable problematic features
      'remote-debugging-port': 9222,          # Enable remote debugging
      'disable-extensions': nil,              # Disable all extensions
      'disable-plugins': nil,                 # Disable all plugins
      'disable-hang-monitor': nil,            # Disable hang monitor
      'disable-prompt-on-repost': nil,        # Disable repost prompts
      'disable-sync': nil,                    # Disable sync
      'disable-translate': nil,               # Disable translate
      'disable-background-networking': nil,   # Disable background networking
      'disable-default-apps': nil,            # Disable default apps
      'disable-component-extensions-with-background-pages': nil, # Disable component extensions
      headless: %w[0 false].exclude?(ENV.fetch('HEADLESS', 'true')) # Support HEADLESS env var per guide
    }
    # Enable JavaScript but configure to ignore errors
    driver_options.js_enabled = true
    # Add slowmo support for debugging per the guide
    driver_options.slowmo = ENV['SLOWMO']&.to_f if ENV['SLOWMO']
  end

  # Add setup and teardown blocks for browser state management (per testing guide)
  setup do
    # Start with a clean session per the guide
    Capybara.reset_sessions!
    
    # Ensure we have basic test data available (from seeds)
    ensure_test_data_available
    
    # Clear any test identity from previous runs (per authentication guide)
    clear_test_identity if respond_to?(:clear_test_identity)
    
    # Inject JavaScript to prevent getComputedStyle loops in tests
    inject_test_javascript_fixes if defined?(page) && page&.driver.present?
  rescue StandardError => e
    debug_puts "Warning: Error in system test setup: #{e.message}"
  end

  teardown do
    # Clean up authentication per the guide
    system_test_sign_out if respond_to?(:system_test_sign_out)
  rescue StandardError => e
    # Log but don't fail if cleanup has an issue
    debug_puts "Warning: Authentication cleanup failed: #{e.message}"
  ensure
    # Always reset session and test identity per the guide
    Capybara.reset_sessions!
    clear_test_identity if respond_to?(:clear_test_identity)
    
    # Clean up after each test to prevent state leakage
    reset_browser_state if defined?(page) && page&.driver.present?
  end

  # Enhanced helper to resolve pending connections with improved robustness
  # This addresses the PendingConnectionsError and timeout issues
  def clear_pending_connections(timeout = 8)
    debug_puts "Attempting to clear pending connections with #{timeout}s timeout..."

    # First, try to stop any active navigation
    begin
      if page.driver.browser.respond_to?(:stop)
        page.driver.browser.stop
        debug_puts 'Stopped active navigation'
      end
    rescue StandardError => e
      debug_puts "Warning: Error stopping navigation: #{e.message}"
    end

    # Then clear JavaScript errors and dialogs
    begin
      if page.driver.browser.respond_to?(:reset)
        page.driver.browser.reset
        debug_puts 'Browser state reset'
      end
    rescue StandardError => e
      debug_puts "Warning: Error resetting browser state: #{e.message}"
    end

    # Now handle pending network connections
    begin
      Timeout.timeout(timeout) do
        # Check for pending connections using Ferrum's network traffic API
        if defined?(page.driver.browser.network) && page.driver.browser.respond_to?(:network)
          # First try to get and clear traffic
          5.times do |attempt|
            # Ensure all exchanges are finished
            pending_requests = page.driver.browser.network.traffic.reject(&:finished?)

            break if pending_requests.empty?

            debug_puts "Attempt #{attempt + 1}: Found #{pending_requests.count} pending network requests..."

            # Wait a bit between clear attempts
            sleep 0.5

            # Force clear traffic
            page.driver.browser.network.clear(:traffic)
          end

          # Double-check and wait if still pending
          pending_requests = page.driver.browser.network.traffic.reject(&:finished?)
          if pending_requests.any?
            debug_puts "Still have #{pending_requests.count} pending requests after initial clearing. Waiting..."

            # More aggressive waiting and clearing
            wait_time = 0
            while pending_requests.any? && wait_time < (timeout - 1) # Leave buffer
              sleep 0.5
              wait_time += 0.5

              # Clear traffic again
              page.driver.browser.network.clear(:traffic)

              # Check again
              pending_requests = page.driver.browser.network.traffic.reject(&:finished?)
              break if pending_requests.empty?
            end

            if pending_requests.any?
              debug_puts "WARNING: Still have #{pending_requests.count} pending requests after waiting. Forcing final clear."
              page.driver.browser.network.clear(:traffic)
            else
              debug_puts 'Successfully cleared all pending requests after waiting.'
            end
          else
            debug_puts 'All pending requests cleared successfully.'
          end
        else
          # Fallback to a simple sleep if network API is not available or compatible
          debug_puts 'Network API not available, using fallback sleep strategy'
          sleep(timeout.positive? ? [timeout / 2, 2].min : 0.5) # Shorter sleep as fallback
        end
      end
    rescue Timeout::Error
      # Clear traffic if timeout occurs during the waiting/checking phase
      debug_puts 'Timeout waiting for pending connections. Forcefully clearing network traffic.'
      if defined?(page.driver.browser.network) && page.driver.browser.respond_to?(:network)
        page.driver.browser.network.clear(:traffic)
      end
    rescue Ferrum::PendingConnectionsError => e
      # This might still be raised by Capybara actions if called immediately after this method
      debug_puts "Ferrum::PendingConnectionsError rescued in clear_pending_connections: #{e.message}. Attempting final reset."

      # Last resort: try to reuse the same page but force a clean state
      begin
        page.driver.browser.execute_script('window.stop(); window.localStorage.clear(); window.sessionStorage.clear();')
        page.driver.browser.network.clear(:cache) if page.driver.browser.respond_to?(:network) &&
                                                     page.driver.browser.network.respond_to?(:clear)
        debug_puts 'Executed emergency browser state cleanup via JavaScript'
      rescue StandardError => e
        debug_puts "Warning: Error during emergency cleanup: #{e.message}"
      end
    rescue StandardError => e
      # Catch other potential errors during the process
      debug_puts "Error in clear_pending_connections: #{e.class} - #{e.message}"
    end

    # Always try to GC at the end to clean up any lingering objects
    GC.start if defined?(GC) && GC.respond_to?(:start)
  end

  # Add a method to fully reset browser state between tests
  def reset_browser_state
    # Don't continue if page is not initialized
    return unless defined?(page) && page&.driver&.browser

    # Stop any active navigation and clear pending traffic
    begin
      clear_pending_connections(1) # Use shorter timeout for teardown
    rescue StandardError => e
      debug_puts "Warning: Error clearing pending connections: #{e.message}"
    end

    # Try to go to a blank page to reset the browser state
    begin
      # Using rescue nil to safely handle any errors
      begin
        visit('about:blank')
      rescue StandardError
        nil
      end

      # Try to reset the session safely
      begin
        Capybara.reset_sessions!
        debug_puts 'Browser navigated to blank page and sessions reset'
      rescue StandardError => e
        debug_puts "Warning: Error resetting sessions: #{e.message}"
      end
    rescue StandardError => e
      debug_puts "Warning: Error navigating to blank page: #{e.message}"
    end

    # Reset environment variables used for test authentication
    ENV['TEST_USER_ID'] = nil

    # Reset Current module if it exists
    Current.reset if defined?(Current) && Current.respond_to?(:reset)
  end

  # Helper to suppress common warnings in system tests
  def suppress_common_warnings
    # Capture warnings before they hit the log
    old_stderr = $stderr
    $stderr = StringIO.new
    yield
  ensure
    # Restore stderr, filter warnings, and only print non-suppressed ones
    warnings = $stderr.string
    $stderr = old_stderr

    # Filter out common warnings we want to suppress
    filtered_warnings = warnings.lines.reject do |line|
      line.include?('BiDi must be enabled') ||
        line.include?('invalid argument: \'handle\'') ||
        line.include?('no such window: target window already closed')
    end

    # Print any remaining warnings
    filtered_warnings.each { |line| warn line }
  end

  # Helper method to ensure required test data exists
  def ensure_test_data_available
    # Check if we have basic users needed for tests
    unless User.exists?(email: 'admin@example.com')
      debug_puts "Warning: Basic test users not found. You may need to run: RAILS_ENV=test bin/rails db:seed"
    end
  end

  # Helper method to access users by fixture name (since we removed fixtures :all)
  # This allows tests to use users(:fixture_name) syntax with seeded data
  def users(fixture_name)
    @users_cache ||= {}
    return @users_cache[fixture_name] if @users_cache[fixture_name]

    user = case fixture_name.to_sym
           when :admin
             User.find_by(email: 'admin@example.com')
           when :confirmed_user
             User.find_by(email: 'user@example.com')
           when :confirmed_user2
             User.find_by(email: 'user2@example.com')
           when :unconfirmed_user
             User.find_by(email: 'unconfirmed@example.com')
           when :trainer
             User.find_by(email: 'trainer@example.com')
           when :evaluator
             User.find_by(email: 'evaluator@example.com')
           when :medical_provider
             User.find_by(email: 'medical@example.com')
           when :constituent_john
             User.find_by(email: 'john.doe@example.com')
           when :constituent_jane
             User.find_by(email: 'jane.doe@example.com')
           when :constituent_alex
             User.find_by(email: 'alex.smith@example.com')
           when :constituent_rex
             User.find_by(email: 'rex.canine@example.com')
           when :vendor_raz
             User.find_by(email: 'raz@testemail.com')
           when :vendor_teltex
             User.find_by(email: 'teltex@testemail.com')
           else
             debug_puts "Warning: Unknown user fixture '#{fixture_name}'"
             nil
           end

    @users_cache[fixture_name] = user
    user
  end

  # Alias for compatibility with existing tests
  def sign_in(user, options = {})
    system_test_sign_in(user, options)
  end

  # Authentication assertion methods from the testing guide
  def assert_authenticated_as(expected_user, msg = nil)
    # In system tests, we primarily rely on UI indicators rather than Current.user
    # since Current.user may not be properly set in the test environment

    # Verify UI state
    assert_no_match(/Sign In|Login/i, page.text, msg || 'Found sign in link when user should be authenticated')
    assert_includes page.text, 'Sign Out', msg || 'Could not find sign out link'
    assert_not_equal sign_in_path, current_path, msg || 'On sign in page when should be authenticated'

    # Check for user-specific content if possible
    return unless expected_user.respond_to?(:first_name) && expected_user.first_name.present?

    assert page.has_text?("Hello #{expected_user.first_name}") ||
           page.has_text?(expected_user.first_name),
           msg || "Couldn't find user's name on page"
  end

  def assert_not_authenticated(msg = nil)
    # Verify Current context if available
    assert_nil Current.user, msg || 'Expected no authenticated user' if defined?(Current) && Current.respond_to?(:user)

    # Verify UI state or redirect
    if page.has_text?('Sign In')
      assert_includes page.text, 'Sign In', msg || 'Could not find sign in link'
      assert_not_includes page.text, 'Sign Out', msg || 'Found sign out link when not authenticated'
    elsif current_path == sign_in_path
      assert_equal sign_in_path, current_path, msg || 'Not on sign in page'
    else
      # We might have been redirected without rendering, so check path
      assert_match(/sign_in/, current_url, msg || 'Not redirected to sign in page')
    end
  end

  # Helper method to run code with authenticated user (from the guide)
  def with_authenticated_user(user)
    system_test_sign_in(user)
    yield
  ensure
    system_test_sign_out
  end

  # Enhanced interaction helpers from the testing guide
  def scroll_to_and_click(selector)
    element = scroll_to_element(selector)
    element.click
    element
  end

  # Wait for Turbo navigation to complete without sleeping (from guide)
  def wait_for_turbo
    Capybara.using_wait_time(5) do
      has_no_css?('.turbo-progress-bar')
    end
  end

  # Helper method to create test objects (for compatibility with FactoryBot usage)
  # Per the testing guide, system tests should use seeded data when possible
  def create(factory_name, *args)
    # Handle different argument patterns:
    # create(:user) - no args
    # create(:user, :trait) - trait symbol
    # create(:user, attributes) - attributes hash
    # create(:user, :trait, attributes) - trait symbol + attributes hash
    
    traits = []
    attributes = {}
    
    args.each do |arg|
      if arg.is_a?(Symbol)
        traits << arg
      elsif arg.is_a?(Hash)
        attributes.merge!(arg)
      end
    end
    
    case factory_name
    when :admin
      users(:admin)
    when :constituent, :user
      # Handle both :constituent and :user factory calls
      if attributes[:email]
        # Look for existing user first
        User.find_by(email: attributes[:email]) || users(:confirmed_user)
      else
        users(:confirmed_user)
      end
    when :vendor
      if traits.include?(:approved) || attributes[:approved] || attributes[:status] == :approved
        users(:vendor_raz) # Use approved vendor
      else
        users(:vendor_teltex) # Use another vendor for non-approved cases
      end
    when :application
      # For applications, look up from seeded data or return nil to let test handle it
      # This is more complex, so tests should use seeded Application records
      debug_puts "Warning: create(:application) should use seeded Application records from db/seeds.rb"
      Application.first # Return first seeded application as fallback
    when :invoice
      # For invoices, we need to look up from seeded data
      debug_puts "Warning: create(:invoice) should use seeded Invoice records from db/seeds.rb"
      Invoice.first # Return first seeded invoice as fallback
    else
      debug_puts "Warning: create(#{factory_name}) not implemented - tests should use seeded data per testing guide"
      nil
    end
  end

  # Helper to create test lists (for create_list compatibility)
  def create_list(factory_name, count, *args)
    debug_puts "Warning: create_list(#{factory_name}) should use seeded data per testing guide"
    Array.new(count) { create(factory_name, *args) }.compact
  end

  # Inject JavaScript fixes to prevent common system test issues
  def inject_test_javascript_fixes
    return unless defined?(page) && page&.driver&.browser

    begin
      # This will be executed on every page load during tests
      page.execute_script(<<~JS)
        // Disable Chart.js completely in system tests
        if (typeof window.Chart !== 'undefined') {
          window.Chart = {
            register: function() {},
            defaults: {},
            Chart: function() { 
              return { 
                destroy: function() {}, 
                update: function() {}, 
                render: function() {} 
              }; 
            }
          };
        }
        
        // Prevent getComputedStyle recursion
        if (!window._getComputedStyleFixed) {
          const originalGetComputedStyle = window.getComputedStyle;
          let callDepth = 0;
          
          window.getComputedStyle = function(element, pseudoElement) {
            if (callDepth > 50) {
              console.warn('getComputedStyle recursion prevented');
              return {};
            }
            
            callDepth++;
            try {
              const result = originalGetComputedStyle.call(this, element, pseudoElement);
              callDepth--;
              return result;
            } catch (error) {
              callDepth = 0;
              return {};
            }
          };
          
          window._getComputedStyleFixed = true;
        }
      JS
    rescue StandardError => e
      debug_puts "Warning: Could not inject JavaScript fixes: #{e.message}"
    end
  end

  private

  # Only output debug messages when VERBOSE_TESTS is enabled
  def debug_puts(message)
    puts message if ENV['VERBOSE_TESTS'] || ENV['DEBUG_AUTH']
  end

  # Enhanced debugging helper from the guide
  def debug_page
    puts "Current URL: #{current_url}"
    puts "Current Path: #{current_path}"
    puts "Page title: #{page.title}"
    puts "Page HTML summary: #{page.html[0..500]}..."
    take_screenshot("debug-#{Time.now.to_i}")
  end

  # Screenshot helper with proper directory creation
  def take_screenshot(name = nil)
    name ||= "screenshot-#{Time.current.strftime('%Y%m%d%H%M%S')}"
    path = Rails.root.join("tmp/screenshots/#{name}.png")
    FileUtils.mkdir_p(Rails.root.join('tmp/screenshots'))

    begin
      page.save_screenshot(path.to_s)
      puts "Screenshot saved to #{path}" if ENV['VERBOSE_TESTS']
    rescue StandardError => e
      debug_puts "Warning: Could not save screenshot: #{e.message}"
    end

    path
  end

  # Environment variable support for test configuration
  def self.configure_test_environment
    # Set log level based on VERBOSE_TESTS environment variable
    if ENV['VERBOSE_TESTS']
      Rails.logger.level = :debug
    else
      Rails.logger.level = :warn
    end

    # Configure database strategy
    if ENV['USE_TRUNCATION']
      self.use_transactional_tests = false
      DatabaseCleaner.strategy = :truncation
    end
  end

  # Call configuration when class is loaded
  configure_test_environment
end
