# frozen_string_literal: true

# SystemTestAuthentication
#
# This module provides enhanced authentication capabilities for system tests.
# It integrates with Capybara via Cuprite, Minitest, and the application's authentication system
# to ensure consistent and reliable user authentication in system tests.
module SystemTestAuthentication
  extend ActiveSupport::Concern
  include AuthenticationCore

  included do
    # Reset the session and clear identity at the beginning of each test
    # This ensures no stale state leaks into the first test
    setup do
      # Reset the browser session
      Capybara.reset_sessions!
      # Clear any test identity from previous runs
      clear_test_identity
      # Configure Cuprite for this test
      self.class.configure_cuprite if defined?(self.class.configure_cuprite)
    end

    # Also reset the session in teardown for good measure
    teardown do
      # Clean up authentication
      system_test_sign_out
    rescue StandardError => e
      # Log but don't fail if cleanup has an issue
      debug_auth "Warning: Authentication cleanup failed: #{e.message}"
    ensure
      # Always reset session and test identity
      Capybara.reset_sessions!
      clear_test_identity
    end
  end

  # Configure Cuprite for system tests if it hasn't been configured
  def self.configure_cuprite
    return if @cuprite_configured

    Capybara.register_driver :cuprite do |app|
      Capybara::Cuprite::Driver.new(app, {
                                      js_errors: ENV.fetch('JS_ERRORS', 'false') == 'true',
                                      headless: %w[0 false].exclude?(ENV.fetch('HEADLESS', nil)),
                                      slowmo: ENV['SLOWMO']&.to_f,
                                      process_timeout: 15,
                                      timeout: 10,
                                      browser_options: ENV['DOCKER'] ? { 'no-sandbox' => nil } : {}
                                    })
    end

    # Disable CSS transitions and animations for faster tests
    Capybara.disable_animation = true if Capybara.respond_to?(:disable_animation=)

    @cuprite_configured = true
  end

  # Wait for Turbo navigation to complete without sleeping
  def wait_for_turbo
    Capybara.using_wait_time(5) do
      has_no_css?('.turbo-progress-bar')
    end
  end

  # Custom assertions for authentication
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

  def system_test_sign_in(user, options = {})
    # Auto-create a fallback admin user if none supplied.
    # Some legacy tests call system_test_sign_in(nil) – rather than blowing
    # up with a NoMethodError, we create a minimal user so the rest of the
    # flow can execute and the tests can focus on their actual intent.
    if user.nil?
      debug_auth 'No user supplied to system_test_sign_in – creating fallback Admin user' if respond_to?(:debug_auth)
      user = FactoryBot.create(:admin)
    end

    # Check if already signed in as this user to avoid redundant sign-ins
    begin
      if user.first_name.present? &&
         page.has_text?("Hello #{user.first_name}") &&
         page.has_text?('Sign Out') &&
         current_path.exclude?('sign_in')
        debug_auth "Already signed in as #{user.first_name}, skipping sign-in process"
        return user
      end
    rescue Ferrum::NodeNotFoundError, Ferrum::TimeoutError => e
      debug_auth "Error checking if already signed in: #{e.message}"
      # Continue with sign-in process
    end

    # Clear identity and visit sign-in page
    clear_test_identity
    visit sign_in_path
    wait_for_turbo

    # Debug information
    debug_auth "Attempting to sign in as #{user.email}"

    # Try multiple form selectors since we have different sign-in forms
    form_selectors = [
      'form#sign_in_form',                        # For the partial with ID
      'form[action*="sign_in"]',                  # For forms posting to sign_in path
      'form:has(input[id="email-input"])',       # For forms with our specific email input
      'form:has(input[type="email"])'            # Most general fallback
    ]

    # Find the first matching form selector
    form_selector = form_selectors.find do |selector|
      page.has_selector?(selector, wait: 2)
    end

    # If no form found, use the most general one
    form_selector ||= 'form:has(input[type="email"])'

    debug_auth "Using form selector: #{form_selector}"

    # Now use the form we found
    begin
      within form_selector do
        # Use the specific field IDs from our form structure
        find_by_id('email-input').set(user.email)
        debug_auth 'Filled email using #email-input'

        find_by_id('password-input').set(options[:password] || 'password123')
        debug_auth 'Filled password using #password-input'

        # Click the submit button
        click_button 'Sign In'
        debug_auth 'Clicked Sign In button'
      end
    rescue Ferrum::NodeNotFoundError, Capybara::ElementNotFound => e
      debug_auth "Error during form interaction: #{e.message}"
      debug_auth "Current URL: #{current_url}"
      debug_auth "Page title: #{page.title}"
      raise StandardError, e.message
    end

    wait_for_turbo

    # Verify successful authentication by visiting a protected page
    if options[:verify_path]
      assert_current_path(options[:verify_path])
    else
      target_path = admin_dashboard_path
      visit target_path unless current_path.include?('two_factor_authentication')
      wait_for_turbo
    end

    # Assert authentication success using pure assertions
    # These will automatically retry until timeout
    assert_not_equal sign_in_path, current_path, 'Redirected to sign-in page after login attempt'
    unless current_path.include?('two_factor_authentication') || options[:verify_path]
      # Look for sign out link or button with various possible text
      sign_out_found = page.has_selector?('a', text: 'Sign Out') ||
                       page.has_selector?('a', text: 'Logout') ||
                       page.has_selector?('a', text: 'Log Out') ||
                       page.has_selector?('button', text: 'Sign Out') ||
                       page.has_selector?('input[type="submit"][value*="Sign Out"]') ||
                       page.has_text?('Secure Account') # Admin interface uses this

      assert sign_out_found, 'Could not find sign out link or authenticated user indicator'
    end

    if current_path.exclude?('two_factor_authentication') && !options[:verify_path]
      if user.first_name.present?
        greeting_pattern = /#{user.first_name}|Hello #{user.first_name}/i
        assert page.has_text?(greeting_pattern), 'User greeting not found after authentication'
      else
        debug_auth 'Skipping greeting check - user has no first_name'
      end
    end

    # Set thread identity and Current.user
    store_test_user_id(user.id)
    update_current_user(user)
    Current.user = user

    # NOTE: For users with 2FA enabled in system tests, the session setup
    # happens through the actual SessionsController flow when we submit the form
    # We don't need to manually set up the 2FA session here

    debug_auth "Successfully signed in as #{user.email}"
    user
  end

  def with_authenticated_user(user)
    original_user_id = Thread.current[:test_user_id]
    # Current.user restoration is handled by clear_test_identity in teardown

    begin
      system_test_sign_in(user) # Perform sign-in
      yield if block_given?
    ensure
      # Restore original Thread.current state
      store_test_user_id(original_user_id)
      # system_test_sign_out (called in main teardown) will handle Capybara session reset
    end
  end

  def system_test_sign_out
    # Clear test identity
    clear_test_identity

    # Use the shared cookie deletion logic
    delete_session_cookie

    # Attempt to click sign out link if visible - don't fail if not found
    begin
      if page.has_link?('Sign Out', wait: 1)
        click_link 'Sign Out'
        wait_for_turbo
      elsif page.has_button?('Sign Out', wait: 1)
        click_button 'Sign Out'
        wait_for_turbo
      end
    rescue Capybara::ElementNotFound => e
      debug_auth "No sign out element found: #{e.message}"
    end

    # Reset Capybara session
    Capybara.reset_sessions!
  end

  # Scroll to an element then interact with it (helpful for Cuprite)
  def scroll_to_element(selector)
    element = find(selector)
    page.driver.scroll_to(element.native, align: :center) if page.driver.respond_to?(:scroll_to)
    element
  end

  # Click an element after scrolling to it
  def scroll_to_and_click(selector)
    element = scroll_to_element(selector)
    element.click
    wait_for_turbo
  end

  # Flash a message in the browser (for debugging)
  def flash_message(message, type = :notice)
    page.execute_script(<<~JS)
      (function() {
        var flashDiv = document.createElement('div');
        flashDiv.textContent = "#{message}";
        flashDiv.className = "flash flash-#{type}";
        flashDiv.style.position = 'fixed';
        flashDiv.style.top = '0';
        flashDiv.style.left = '0';
        flashDiv.style.width = '100%';
        flashDiv.style.padding = '10px';
        flashDiv.style.backgroundColor = '#{type == :error ? 'red' : 'green'}';
        flashDiv.style.color = 'white';
        flashDiv.style.zIndex = '9999';
        flashDiv.style.textAlign = 'center';
        document.body.appendChild(flashDiv);
        setTimeout(function() {
          flashDiv.remove();
        }, 3000);
      })();
    JS
  end
end
