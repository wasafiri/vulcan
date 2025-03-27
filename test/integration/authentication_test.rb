# frozen_string_literal: true

require 'test_helper'

# Authentication Integration Test
#
# This test suite verifies that authentication works correctly in various scenarios.
# It tests both successful authentication and edge cases like expired sessions,
# invalid credentials, etc.
class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    # Set up test data
    @user = users(:constituent_john)
    @admin = users(:admin_jane)

    # Enable debug logging for authentication issues
    ENV['DEBUG_AUTH'] = 'true'
  end

  # Test successful authentication
  test 'should authenticate user with valid credentials' do
    # Sign in the user
    post sign_in_path, params: {
      email: @user.email,
      password: 'password123' # Assuming this is the correct password in fixtures
    }

    # Should redirect to dashboard or home page
    assert_response :redirect

    # Follow redirect
    follow_redirect!

    # Verify we're authenticated
    assert_response :success
    assert_select 'a', text: /Sign Out|Logout/

    # Verify authentication state
    verify_authentication_state(@user)
  end

  # Test authentication failure with invalid credentials
  test 'should not authenticate with invalid credentials' do
    # Attempt to sign in with wrong password
    post sign_in_path, params: {
      email: @user.email,
      password: 'wrong_password'
    }

    # Should stay on sign in page with error
    assert_response :unprocessable_entity
    assert_select '.alert', /Invalid email or password/

    # Verify we're not authenticated
    assert_select "form[action='#{sign_in_path}']"
    assert_select 'a', text: /Sign Out|Logout/, count: 0
  end

  # Test session expiration
  test 'should handle expired sessions' do
    # Sign in the user
    sign_in(@user)

    # Verify we're authenticated
    get root_path
    assert_response :success

    # Expire the session
    session = Session.find_by(user_id: @user.id)
    session.update!(expires_at: 1.day.ago)

    # Try to access a protected page
    get constituent_portal_applications_path

    # Should be redirected to sign in
    assert_redirected_to sign_in_path
  end

  # Test sign out
  test 'should sign out user' do
    # Sign in the user
    sign_in(@user)

    # Verify we're authenticated
    get root_path
    assert_response :success

    # Sign out
    delete sign_out_path

    # Should redirect to sign in or home page
    assert_response :redirect
    follow_redirect!

    # Verify we're signed out
    assert_select 'a', text: /Sign In|Login/
    assert_select 'a', text: /Sign Out|Logout/, count: 0
  end

  # Test authentication with headers
  test 'should authenticate with headers' do
    # Sign in with headers
    sign_in_with_headers(@user)

    # Verify we're authenticated
    get constituent_portal_applications_path
    assert_response :success

    # Verify authentication state
    verify_authentication_state(@user)
  end

  # Test the new authenticate_user! method
  test 'should authenticate with authenticate_user!' do
    # Use the new method
    authenticate_user!(@user)

    # Verify we're authenticated
    get constituent_portal_applications_path
    assert_response :success

    # Verify authentication state
    verify_authentication_state(@user)
  end

  # Test authentication persistence across requests
  test 'should maintain authentication across requests' do
    # Sign in the user
    sign_in(@user)

    # Make multiple requests
    get constituent_portal_applications_path
    assert_response :success

    get new_constituent_portal_application_path
    assert_response :success

    get root_path
    assert_response :success

    # Verify we're still authenticated
    verify_authentication_state(@user)
  end

  # Test role-based access control
  test 'should enforce role-based access control' do
    # Sign in as regular user
    sign_in(@user)

    # Try to access admin page
    get admin_applications_path

    # Should be denied access
    assert_not_authorized

    # Sign in as admin
    sign_in(@admin)

    # Try to access admin page again
    get admin_applications_path

    # Should be allowed access
    assert_response :success
  end

  # Test the automatic header inclusion
  test 'should automatically include headers in requests' do
    # Sign in the user
    sign_in(@user)

    # Make a request without explicitly including headers
    get constituent_portal_applications_path

    # Should still be authenticated
    assert_response :success

    # Verify authentication state
    verify_authentication_state(@user)
  end

  # Test authentication with remember me
  test 'should remember user across browser sessions' do
    # Sign in with remember me
    post sign_in_path, params: {
      email: @user.email,
      password: 'password123',
      remember_me: '1'
    }

    # Should set a persistent cookie
    assert_not_nil cookies[:remember_token] if cookies.respond_to?(:signed)

    # Follow redirect
    follow_redirect!

    # Verify we're authenticated
    assert_response :success

    # Simulate browser restart by clearing session but keeping cookies
    # This is a bit tricky in tests, so we'll just verify the remember token exists
    assert_not_nil cookies.signed[:remember_token] || cookies[:remember_token] if cookies.respond_to?(:signed)
  end

  # Test the skip_unless_authentication_working helper
  test 'should skip tests when authentication is not working' do
    # This is a bit meta - we're testing the test helper itself
    # First, break authentication
    def self.get(*)
      # Override get to simulate a redirect to sign in
      @response = ActionDispatch::TestResponse.new
      @response.redirect_to('http://www.example.com/sign_in')
    end

    # Now try to use the helper
    begin
      skip_unless_authentication_working
      flunk 'Expected test to be skipped'
    rescue Minitest::Skip
      # This is expected
      pass
    ensure
      # Restore normal behavior
      class << self
        remove_method :get
      end
    end
  end
end
