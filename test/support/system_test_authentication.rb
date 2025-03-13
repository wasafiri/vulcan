# frozen_string_literal: true

# SystemTestAuthentication
#
# This module provides enhanced authentication capabilities for system tests
# It integrates with Capybara, Minitest, and the application's authentication system
# to ensure consistent and reliable user authentication in system tests.
module SystemTestAuthentication
  extend ActiveSupport::Concern

  included do
    setup do
      # Reset authentication state
      Capybara.reset_sessions!
      ENV["TEST_USER_ID"] = nil
      Current.reset if defined?(Current)
    end

    teardown do
      # Clean up authentication
      begin
        system_test_sign_out
      rescue => e
        # Log but don't fail if cleanup has an issue
        puts "Warning: Authentication cleanup failed: #{e.message}"
      ensure
        # Always reset session and env var
        Capybara.reset_sessions!
        ENV["TEST_USER_ID"] = nil
        Current.reset if defined?(Current)
      end
    end
  end

  # Custom assertions for authentication
  def assert_authenticated_as(expected_user, msg = nil)
    # In system tests, we primarily rely on UI indicators rather than Current.user
    # since Current.user may not be properly set in the test environment
    
    # Verify UI state
    assert_no_match(/Sign In|Login/i, page.text, msg || "Found sign in link when user should be authenticated")
    assert_includes page.text, "Sign Out", msg || "Could not find sign out link"
    assert_not_equal sign_in_path, current_path, msg || "On sign in page when should be authenticated"
    
    # Check for user-specific content if possible
    if expected_user.respond_to?(:first_name) && expected_user.first_name.present?
      assert page.has_text?("Hello #{expected_user.first_name}") || 
             page.has_text?(expected_user.first_name), 
             msg || "Couldn't find user's name on page"
    end
  end

  def assert_not_authenticated(msg = nil)
    # Verify Current context if available
    if defined?(Current) && Current.respond_to?(:user)
      assert_nil Current.user, msg || "Expected no authenticated user"
    end
    
    # Verify UI state or redirect
    if page.has_text?("Sign In")
      assert_includes page.text, "Sign In", msg || "Could not find sign in link"
      assert_not_includes page.text, "Sign Out", msg || "Found sign out link when not authenticated"
    elsif current_path == sign_in_path
      assert_equal sign_in_path, current_path, msg || "Not on sign in page"
    else
      # We might have been redirected without rendering, so check path
      assert_match(/sign_in/, current_url, msg || "Not redirected to sign in page")
    end
  end

  def system_test_sign_in(user)
    # Create session record first
    test_session = user.sessions.create!(
      user_agent: "Rails System Test",
      ip_address: "127.0.0.1"
    )
    
    # Set test environment identifier
    ENV["TEST_USER_ID"] = user.id.to_s
    
    # First check if we're already logged in
    visit root_path
    wait_for_turbo if respond_to?(:wait_for_turbo)
    
    # Debug information
    puts "Current path: #{current_path}"
    puts "Page has Sign Out button? #{page.has_button?('Sign Out')}"
    puts "Page has Sign Out link? #{page.has_link?('Sign Out')}"
    puts "Page text includes 'Hello #{user.first_name}'? #{page.has_text?("Hello #{user.first_name}")}"
    
    # If we're already logged in, we don't need to go through sign in flow
    if page.has_text?("Hello #{user.first_name}") || 
       page.has_button?("Sign Out") || 
       page.has_link?("Sign Out")
      puts "User already signed in, skipping sign in form"
      return test_session
    end
    
    # Otherwise, go through sign in flow
    visit sign_in_path
    wait_for_turbo if respond_to?(:wait_for_turbo)
    
    # Find the form
    within("form") do
      # Try different methods to find the right field
      begin
        fill_in "email-input", with: user.email
      rescue Capybara::ElementNotFound
        fill_in "email", with: user.email
      end
      
      begin
        fill_in "password-input", with: "password123"
      rescue Capybara::ElementNotFound
        fill_in "password", with: "password123"
      end
      
      click_button "Sign In"
    end
    
    # Wait for Turbo navigation
    wait_for_turbo if respond_to?(:wait_for_turbo)
    
    # Set cookies via Capybara/Selenium for extra reliability
    page.driver.browser.manage.add_cookie(
      name: 'session_token',
      value: test_session.session_token
    )
    
    # Verify successful authentication
    if page.has_text?("Signed in successfully")
      # Success! We're good to go
    elsif defined?(response) && response.redirect? && response.location.include?("sign_in")
      flunk "Failed to authenticate: Redirected back to sign in"
    else
      flunk "Failed to authenticate: No success message found"
    end
    
    # Return the session for potential cleanup
    test_session
  end

  def with_authenticated_user(user)
    original_user = Current.user if defined?(Current)
    original_user_id = ENV["TEST_USER_ID"]
    session = nil

    begin
      session = system_test_sign_in(user)
      yield if block_given?
    ensure
      # Restore original state
      ENV["TEST_USER_ID"] = original_user_id
      Current.user = original_user if defined?(Current)
      session&.destroy
    end
  end

  def system_test_sign_out
    # Only attempt if we're actually on a page
    return unless page.driver.browser.manage&.respond_to?(:delete_cookie)
    
    # Delete cookie first to ensure clean state
    page.driver.browser.manage.delete_cookie('session_token')
    
    # Clear environment variable
    ENV["TEST_USER_ID"] = nil
    
    # Attempt to click sign out link if visible
    if page.has_link?("Sign Out")
      click_link "Sign Out"
      wait_for_turbo if respond_to?(:wait_for_turbo)
    elsif page.has_button?("Sign Out")
      click_button "Sign Out"
      wait_for_turbo if respond_to?(:wait_for_turbo)
    end
    
    # Reset Capybara session
    Capybara.reset_sessions!
    
    # Clear Current attributes
    Current.reset if defined?(Current)
  end

  private

  def reset_test_state
    ENV["TEST_USER_ID"] = nil
    Current.reset if defined?(Current)
  end
end
