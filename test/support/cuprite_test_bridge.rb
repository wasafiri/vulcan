# frozen_string_literal: true

# This module serves as a bridge between the core system_test_authentication module
# and our Cuprite-specific helpers, providing safer error handling and performance
# improvements for Cuprite-based system tests.
module CupriteTestBridge
  # Safe browser interaction that recovers from common Cuprite/Ferrum errors
  def safe_interaction
    yield
  rescue StandardError => e
    if e.class.to_s =~ /Ferrum::(DeadBrowserError|NoSuchWindowError|NodeNotFoundError)/
      puts "Recovering from Cuprite error: #{e.class} - #{e.message}"
      Capybara.reset_sessions! # Force a clean browser state
    else
      puts "Error during browser interaction: #{e.class} - #{e.message}"
    end
    false
  end

  # Enhanced version of system_test_sign_in that's more resilient with Cuprite
  def enhanced_sign_in(user)
    return nil unless user&.respond_to?(:sessions)

    # Create session record first, just like the original
    test_session = user.sessions.create!(
      user_agent: 'Rails System Test',
      ip_address: '127.0.0.1'
    )

    # Set environment variable
    ENV['TEST_USER_ID'] = user.id.to_s

    # Visit the root path with error handling
    safe_interaction do
      visit root_path
      # No sleep needed - just wait for Turbo
      has_no_css?('.turbo-progress-bar', wait: 2)
    end

    # If already signed in, return early
    return test_session if page.has_text?('Sign Out') || page.has_button?('Sign Out')

    # Try to sign in
    safe_interaction do
      visit sign_in_path

      # Find and fill in the form
      if page.has_field?('email') || page.has_field?('email-input')
        # Find email field
        email_field = page.has_field?('email-input') ? 'email-input' : 'email'
        fill_in email_field, with: user.email

        # Find password field
        password_field = page.has_field?('password-input') ? 'password-input' : 'password'
        fill_in password_field, with: 'password123'

        # Submit form
        click_button 'Sign In'
      end
    end

    # Set cookies directly to help with authentication
    if page.driver.is_a?(Capybara::Cuprite::Driver) && page.driver.respond_to?(:set_cookie)
      safe_interaction do
        page.driver.set_cookie('session_token', test_session.session_token)
      end
    end

    # Refresh to apply cookie
    safe_interaction { visit current_path }

    # Navigate to root to verify greeting
    safe_visit root_path

    # Return the session
    test_session
  end

  # Enhanced version of system_test_sign_out that's more resilient
  def enhanced_sign_out
    # Clear environment variable
    ENV['TEST_USER_ID'] = nil

    # Handle cookie deletion with error recovery
    if page.driver.is_a?(Capybara::Cuprite::Driver)
      safe_interaction do
        if page.driver.respond_to?(:remove_cookie)
          page.driver.remove_cookie('session_token')
        elsif page.driver.respond_to?(:clear_cookies)
          page.driver.clear_cookies
        end
      end
    end

    # Try to click sign out if visible
    safe_interaction do
      if page.has_link?('Sign Out')
        click_link 'Sign Out'
      elsif page.has_button?('Sign Out')
        click_button 'Sign Out'
      end
    end

    # Reset Current if available
    Current.reset if defined?(Current)
  end

  # Helper to wait for page loads without blocking too long
  def wait_for_page_load(max_wait = 2)
    # Check for Turbo progress bar
    Capybara.using_wait_time(max_wait) do
      has_no_css?('.turbo-progress-bar')
    end

    # Wait for document ready state in JavaScript
    page.evaluate_script('document.readyState') == 'complete'
  end

  # Safe version of visit that handles browser errors
  def safe_visit(path)
    safe_interaction { visit path }
    wait_for_page_load
  end

  # Safe method to find elements without raising errors
  def safe_find(selector, options = {})
    safe_interaction { find(selector, **options) }
  rescue Capybara::ElementNotFound
    nil
  end

  # Time execution of operations and log metrics
  def measure_time(operation_name)
    start_time = Time.zone.now
    result = yield
    duration = Time.zone.now - start_time
    puts "#{operation_name} took #{duration.round(2)}s"
    result
  end
end
