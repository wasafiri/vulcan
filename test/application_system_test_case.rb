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

  # Configure the browser with increased timeouts for better stability
  # NOTE: This must be at the class level, not inside a setup block
  driven_by :cuprite, using: :chromium, screen_size: [1400, 1400] do |driver_options|
    driver_options.timeout = 180             # Increase default timeouts significantly for CI
    driver_options.process_timeout = 180     # Increase process timeout significantly for CI
    driver_options.js_errors = false         # Don't fail on JS errors
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
      headless: true # Explicitly set headless mode
    }
    # Enable JavaScript but configure to ignore errors
    driver_options.js_enabled = true
    # Enable BiDi for WebSocket-based browser control
    driver_options.web_socket_url = true if driver_options.respond_to?(:web_socket_url=)
  end

  # Add setup and teardown blocks for browser state management
  setup do
    # Start with a clean session
    Capybara.reset_sessions!
    
    # Ensure we have basic test data available (from seeds)
    ensure_test_data_available
    
    # Inject JavaScript to prevent getComputedStyle loops in tests
    inject_test_javascript_fixes if defined?(page) && page&.driver.present?
  rescue StandardError => e
    debug_puts "Warning: Error resetting Capybara session: #{e.message}"
  end

  teardown do
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
    puts message if ENV['VERBOSE_TESTS']
  end
end
