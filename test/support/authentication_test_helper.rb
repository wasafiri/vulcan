# frozen_string_literal: true

# Authentication Test Helper
#
# This module provides consistent methods for handling authentication in tests.
# IMPORTANT: Always use these helpers instead of directly manipulating cookies
# to ensure consistent behavior across different test environments.
#
# NOTE: In production, we always use signed cookies for security.
# In test environments, we attempt to use signed cookies first, but fall back to
# unsigned cookies if necessary. This difference exists because some test
# environments (particularly certain integration tests) don't fully support
# the signed cookie functionality that's available in production.
module AuthenticationTestHelper
  # Standard headers for integration tests
  # @return [Hash] Headers to use for integration tests
  def default_headers
    {
      "HTTP_USER_AGENT" => "Rails Testing",
      "REMOTE_ADDR" => "127.0.0.1"
    }
  end

  # Helper method to set authentication cookie with clear fallback logic
  # @param session_token [String] The session token to store in the cookie
  # @return [void]
  def set_auth_cookie(session_token)
    auth_debug("Setting auth cookie with token: #{session_token}")

    # Always set both signed and unsigned cookies to ensure compatibility
    # with both the controller's current_user method and the test environment
    if cookies.respond_to?(:signed) && cookies.signed.respond_to?(:[]=)
      cookies.signed[:session_token] = { value: session_token, httponly: true }
      auth_debug("Set signed cookie")
    end

    # Also set the unsigned cookie for tests that don't support signed cookies
    cookies[:session_token] = session_token
    auth_debug("Set unsigned cookie")
  end

  # Enhanced sign_in method that works consistently across all test types
  # @param user [User] The user to sign in
  # @param password [String] The password to use for authentication
  # @return [User] The signed-in user (for method chaining)
  def sign_in_with_headers(user, password = "password123")
    auth_debug("Signing in user: #{user.email}")

    if respond_to?(:post)
      # Integration test - go through the sign in flow
      post sign_in_path, params: {
        email: user.email, password: password
      }, headers: default_headers

      auth_debug("After integration test sign_in")

      # For integration tests, we need to follow redirects and ensure we're logged in
      follow_redirect! if response.redirect?

      # Verify the session was created
      session_record = Session.find_by(user_id: user.id)
      if session_record
        # Manually set the cookie for integration tests
        set_auth_cookie(session_record.session_token)
      else
        Rails.logger.warn "WARNING: No session record found for user #{user.email} after sign_in attempt"
      end
    else
      # Controller/Model test - create session directly
      session = user.sessions.create!(
        user_agent: "Rails Testing",
        ip_address: "127.0.0.1"
      )
      set_auth_cookie(session.session_token)
      auth_debug("After controller test sign_in")
    end

    # Return the user for method chaining
    user
  end

  # Verify that the user is authenticated
  # @param expected_user [User] The user that should be authenticated
  # @return [void]
  def assert_authenticated(expected_user)
    if defined?(@controller) && @controller.respond_to?(:current_user, true)
      # Controller test
      current_user = @controller.send(:current_user)
      assert_equal expected_user.id, current_user&.id,
        "Expected to be authenticated as #{expected_user.email}, but was #{current_user&.email || 'not authenticated'}"
    else
      # Integration test - check for signs of authentication
      assert_no_match(/Sign In|Login/, response.body,
        "Expected to be authenticated as #{expected_user.email}, but found sign-in link")
      assert_match(/Sign Out|Logout/, response.body,
        "Expected to be authenticated as #{expected_user.email}, but couldn't find logout link")
    end
  end

  # Verify that the user is not authenticated
  # @return [void]
  def assert_not_authenticated
    if defined?(@controller) && @controller.respond_to?(:current_user, true)
      # Controller test
      current_user = @controller.send(:current_user)
      assert_nil current_user, "Expected not to be authenticated, but was authenticated as #{current_user&.email}"
    else
      # Integration test - check for signs of authentication
      assert_match(/Sign In|Login/, response.body, "Expected not to be authenticated, but couldn't find sign-in link")
      assert_no_match(/Sign Out|Logout/, response.body, "Expected not to be authenticated, but found logout link")
    end
  end

  # Sign out the current user
  # @return [void]
  def sign_out_with_headers
    auth_debug("Signing out user")

    if respond_to?(:delete)
      # Integration test
      delete sign_out_path, headers: default_headers
      follow_redirect! if response.redirect?
    else
      # Controller/Model test - use the helper method for consistency
      remove_auth_cookie
    end
  end

  # Helper method to remove authentication cookie
  # @return [void]
  def remove_auth_cookie
    auth_debug("Removing auth cookie")

    # Always remove both signed and unsigned cookies to ensure consistency
    if cookies.respond_to?(:signed) && cookies.signed.respond_to?(:delete)
      cookies.signed.delete(:session_token)
      auth_debug("Removed signed cookie")
    end

    # Also remove the unsigned cookie
    cookies.delete(:session_token)
    auth_debug("Removed unsigned cookie")
  end

  # Centralized debug logging for authentication
  # @param message [String] The message to log
  # @return [void]
  def auth_debug(message)
    return unless ENV["DEBUG_AUTH"] == "true"
    Rails.logger.debug "[AUTH DEBUG] #{message}"
  end

  # Enhanced authentication helper that abstracts away all the complexity
  # This is the preferred method for authenticating users in tests
  # @param user [User] The user to authenticate (defaults to @user if defined)
  # @return [Hash] Default headers for method chaining
  def authenticate_user!(user = nil)
    user ||= @user if defined?(@user)
    raise "No user provided for authentication" unless user

    auth_debug("Authenticating user: #{user.email} with authenticate_user!")

    # Sign in the user
    sign_in(user)

    # Verify authentication was successful
    debug_auth_state("Authentication verification") if respond_to?(:debug_auth_state)
    
    # For integration tests, verify we're not redirected to sign in
    if defined?(response) && response.present?
      if response.redirect? && response.location.include?("sign_in") 
        fail "Expected to be authenticated as #{user.email}, but was redirected to sign in"
      end
    end
    
    # For controller tests, verify current_user is set correctly
    if defined?(@controller) && @controller.respond_to?(:current_user, true)
      actual_user = @controller.send(:current_user)
      if actual_user.nil?
        fail "Expected to be authenticated as #{user.email}, but current_user is nil"
      elsif actual_user.id != user.id
        fail "Expected to be authenticated as #{user.email}, but was authenticated as #{actual_user.email}"
      end
    end

    # Return headers for method chaining if needed
    default_headers
  end
end
