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
                                      js_errors: true,
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
    # Check if already signed in as this user to avoid redundant sign-ins
    if page.has_text?("Hello #{user.first_name}") &&
       page.has_text?('Sign Out') &&
       current_path.exclude?('sign_in')
      debug_auth "Already signed in as #{user.first_name}, skipping sign-in process"
      return user
    end

    # Clear identity and visit sign-in page
    clear_test_identity
    visit sign_in_path
    wait_for_turbo

    # Debug information
    debug_auth "Attempting to sign in as #{user.email}"

    # Find the right form using a sequence of progressively more general selectors
    form_selectors = [
      'form[data-testid="sign-in-form"]', # Prefer data-testid (most stable)
      'form#sign_in_form',                        # Then try specific ID
      'form.sign-in-form',                        # Then try class
      'form[action*="sign_in"]',                  # Then try form with sign_in in action
      'form:has(input[type="email"], input[name*="email"])' # Most general fallback
    ]

    # Find the first matching form selector
    form_selector = form_selectors.find do |selector|
      page.has_selector?(selector, wait: 2)
    end

    # If no form found, try the generic selectors as a last resort
    form_selector ||= 'form:has(input[type="email"], input[name*="email"])'

    debug_auth "Using form selector: #{form_selector}"

    # Now use the form we found
    within form_selector do
      # Try email field with multiple possible selectors
      email_selectors = [
        '[data-testid="email-input"]',
        '#email',
        'input[name*="email"]',
        'input[type="email"]',
        'input[id*="email"]'
      ]

      # Find first matching email field
      email_selector = email_selectors.find { |selector| page.has_selector?(selector, wait: 1) }

      if email_selector
        debug_auth "Using email selector: #{email_selector}"
        fill_in email_selector, with: user.email
      else
        # Last resort: try filling by field name/label
        begin
          fill_in 'Email', with: user.email
        rescue Capybara::ElementNotFound
          fill_in 'email', with: user.email
        end
      end

      # Try password field with multiple possible selectors
      password_selectors = [
        '[data-testid="password-input"]',
        '#password',
        'input[name*="password"]',
        'input[type="password"]',
        'input[id*="password"]'
      ]

      # Find first matching password field
      password_selector = password_selectors.find { |selector| page.has_selector?(selector, wait: 1) }

      if password_selector
        debug_auth "Using password selector: #{password_selector}"
        fill_in password_selector, with: options[:password] || 'password123'
      else
        # Last resort: try filling by field name/label
        begin
          fill_in 'Password', with: options[:password] || 'password123'
        rescue Capybara::ElementNotFound
          fill_in 'password', with: options[:password] || 'password123'
        end
      end

      # Try to find the sign in button with multiple possible selectors
      button_selectors = [
        '[data-testid="sign-in-button"]',
        'button[type="submit"]',
        'input[type="submit"]',
        'button:contains("Sign In")',
        'input[value*="Sign In"]'
      ]

      # Try each button selector in turn
      button_found = button_selectors.any? do |selector|
        if page.has_selector?(selector, wait: 1)
          debug_auth "Using button selector: #{selector}"
          find(selector).click
          true
        else
          false
        end
      rescue Capybara::ElementNotFound
        false
      end

      # If no button found via selectors, try clicking by text/value
      unless button_found
        begin
          click_button 'Sign In'
        rescue Capybara::ElementNotFound
          begin
            click_button 'Login'
          rescue Capybara::ElementNotFound
            click_on 'Sign In'
          end
        end
      end
    end

    wait_for_turbo

    # Verify successful authentication by visiting a protected page
    target_path = options[:verify_path] || admin_dashboard_path
    visit target_path
    wait_for_turbo

    # Assert authentication success using pure assertions
    # These will automatically retry until timeout
    assert_no_current_path sign_in_path, 'Redirected to sign-in page after login attempt'
    assert_selector 'a', text: 'Sign Out'

    greeting_pattern = /#{user.first_name}|Hello #{user.first_name}/i
    assert page.has_text?(greeting_pattern), 'User greeting not found after authentication'

    # Set thread identity and Current.user
    store_test_user_id(user.id)
    update_current_user(user)

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
