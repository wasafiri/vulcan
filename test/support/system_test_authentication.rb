# frozen_string_literal: true

# SystemTestAuthentication
#
# This module provides enhanced authentication capabilities for system tests
# It integrates with Capybara via Cuprite, Minitest, and the application's authentication system
# to ensure consistent and reliable user authentication in system tests.
module SystemTestAuthentication
  extend ActiveSupport::Concern

  included do
    setup do
      # Reset authentication state
      Capybara.reset_sessions!
      ENV['TEST_USER_ID'] = nil
      Current.reset if defined?(Current)
    end

    teardown do
      # Clean up authentication
      system_test_sign_out
    rescue StandardError => e
      # Log but don't fail if cleanup has an issue
      puts "Warning: Authentication cleanup failed: #{e.message}"
    ensure
      # Always reset session and env var
      Capybara.reset_sessions!
      ENV['TEST_USER_ID'] = nil
      Current.reset if defined?(Current)
    end
  end

  # Configure Cuprite for system tests if it hasn't been configured
  def self.configure_cuprite
    return if @cuprite_configured

    Capybara.register_driver :cuprite do |app|
      Capybara::Cuprite::Driver.new(app, {
        js_errors: true,
        headless: %w[0 false].exclude?(ENV['HEADLESS']),
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

  # Wait for Turbo navigation to complete
  def wait_for_turbo
    sleep 0.1 # Small sleep to give Turbo a chance to start
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

  def system_test_sign_in(user)
    # Create session record first
    test_session = user.sessions.create!(
      user_agent: 'Rails System Test',
      ip_address: '127.0.0.1'
    )

    # Set test environment identifier
    ENV['TEST_USER_ID'] = user.id.to_s

    # First check if we're already logged in
    visit root_path
    wait_for_turbo

    # Debug information
    puts "Current path: #{current_path}"
    puts "Page has Sign Out button? #{page.has_button?('Sign Out')}"
    puts "Page has Sign Out link? #{page.has_link?('Sign Out')}"
    puts "Page text includes 'Hello #{user.first_name}'? #{page.has_text?("Hello #{user.first_name}")}"

    # If we're already logged in, we don't need to go through sign in flow
    if page.has_text?("Hello #{user.first_name}") ||
       page.has_button?('Sign Out') ||
       page.has_link?('Sign Out')
      puts 'User already signed in, skipping sign in form'
      return test_session
    end

    # Otherwise, go through sign in flow
    visit sign_in_path
    wait_for_turbo

    # Find the form
    within('form') do
      # Try different methods to find the right field
      begin
        fill_in 'email-input', with: user.email
      rescue Capybara::ElementNotFound
        fill_in 'email', with: user.email
      end

      begin
        fill_in 'password-input', with: 'password123'
      rescue Capybara::ElementNotFound
        fill_in 'password', with: 'password123'
      end

      click_button 'Sign In'
    end

    # Wait for Turbo navigation
    wait_for_turbo

    # Set cookies based on driver type
    if page.driver.is_a?(Capybara::Selenium::Driver)
      # For Selenium-based drivers
      begin
        page.driver.browser.manage.add_cookie(
          name: 'session_token',
          value: test_session.session_token
        )
      rescue StandardError => e
        puts "Warning: Selenium cookie setting failed: #{e.message}"
      end
    elsif page.driver.is_a?(Capybara::Cuprite::Driver)
      # For Cuprite driver
      begin
        if page.driver.respond_to?(:set_cookie)
          page.driver.set_cookie('session_token', test_session.session_token)
        end
      rescue StandardError => e
        puts "Warning: Cuprite cookie setting failed: #{e.message}"
      end
    end

    # Refresh the page to apply cookie changes
    visit current_path
    wait_for_turbo

    # Verify successful authentication
    if page.has_text?('Signed in successfully') || page.has_link?('Sign Out') || page.has_button?('Sign Out')
      # Success! We're good to go
      puts "Successfully authenticated as #{user.email}" if ENV['DEBUG_AUTH'] == 'true'
    elsif defined?(response) && response.redirect? && response.location.include?('sign_in')
      flunk 'Failed to authenticate: Redirected back to sign in'
    elsif page.has_text?('Invalid email or password') || page.has_text?('Sign In')
      flunk 'Failed to authenticate: Still on sign in page with error'
    else
      puts "WARNING: Authentication state unclear. Current path: #{current_path}, page text includes sign out? #{page.has_text?('Sign Out')}"
    end

    # Return the session for potential cleanup
    test_session
  end

  def with_authenticated_user(user)
    original_user = Current.user if defined?(Current)
    original_user_id = ENV['TEST_USER_ID']
    session = nil

    begin
      session = system_test_sign_in(user)
      yield if block_given?
    ensure
      # Restore original state
      ENV['TEST_USER_ID'] = original_user_id
      Current.user = original_user if defined?(Current)
      session&.destroy
    end
  end

  def system_test_sign_out
    # Clear environment variable first
    ENV['TEST_USER_ID'] = nil

    # Handle cookie deletion based on driver type
    if page.driver.is_a?(Capybara::Selenium::Driver)
      # For Selenium-based drivers
      begin
        page.driver.browser.manage.delete_cookie('session_token') if page.driver.browser.manage.respond_to?(:delete_cookie)
      rescue StandardError => e
        puts "Warning: Selenium cookie deletion failed: #{e.message}"
      end
    elsif page.driver.is_a?(Capybara::Cuprite::Driver)
      # For Cuprite driver
      begin
        if page.driver.respond_to?(:remove_cookie)
          page.driver.remove_cookie('session_token')
        elsif page.driver.respond_to?(:clear_cookies)
          page.driver.clear_cookies
        end
      rescue StandardError => e
        puts "Warning: Cuprite cookie deletion failed: #{e.message}"
      end
    end

    # Attempt to click sign out link if visible
    if page.has_link?('Sign Out')
      click_link 'Sign Out'
      wait_for_turbo
    elsif page.has_button?('Sign Out')
      click_button 'Sign Out'
      wait_for_turbo
    end

    # Reset Capybara session
    Capybara.reset_sessions!

    # Clear Current attributes
    Current.reset if defined?(Current)
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

  private

  def reset_test_state
    ENV['TEST_USER_ID'] = nil
    Current.reset if defined?(Current)
  end
end
