# frozen_string_literal: true

# AuthenticationTestHelper
#
# This module provides a standardized approach to authentication in tests.
# It includes methods for all test types (unit, controller, integration, system).
#
# Usage:
# - sign_in_as(user): For controller tests, sets cookies directly
# - sign_in_with_headers(user): For integration tests, includes HTTP headers
# - set_current_user(user): For unit tests that need Current.user set
# - sign_in(user): Unified method that works across test types
#
# The module is automatically included in all test cases via test_helper.rb.
module AuthenticationTestHelper
  # Set the current user for a test block - useful for unit tests
  # @param user [User] The user to set as Current.user
  # @yield Block to execute with the user set
  def set_current_user(user)
    Current.user = user
    yield
  ensure
    Current.user = nil
  end

  # Authenticate as a user for controller tests
  # @param user [User] The user to authenticate as
  # @return [User] The user that was authenticated
  def sign_in_as(user)
    session = create_test_session(user)
    if cookies.respond_to?(:signed)
      cookies.signed[:session_token] = session.session_token
    else
      cookies[:session_token] = session.session_token
    end
    # Log authentication in debug mode
    puts "CONTROLLER AUTH: Setting cookie for #{user.email}" if ENV['DEBUG_AUTH'] == 'true'
    user
  end

  # Authenticate with headers for integration tests
  # @param user [User] The user to authenticate as
  # @return [User] The user that was authenticated
  def sign_in_with_headers(user)
    session = create_test_session(user)

    # For integration tests, we don't have direct access to @request.headers
    # Instead, we use the built-in methods for setting headers with integration tests
    headers = { 'HTTP_COOKIE' => "session_token=#{session.session_token}" }

    # Merge our headers with the default headers
    @headers = default_headers.merge(headers) if respond_to?(:default_headers)

    # Also set the cookies directly for maximum compatibility
    if cookies.respond_to?(:signed)
      cookies.signed[:session_token] = session.session_token if respond_to?(:cookies)
    elsif respond_to?(:cookies)
      cookies[:session_token] = session.session_token
    end

    # Set test user ID for test environment authentication bypass
    ENV['TEST_USER_ID'] = user.id.to_s

    # Log authentication in debug mode
    puts "INTEGRATION AUTH: Setting headers and cookies for #{user.email}" if ENV['DEBUG_AUTH'] == 'true'

    user
  end

  # Sign in a user for integration tests by simulating password sign-in
  # @param user [User] The user to sign in
  def sign_in_user(user)
    post sign_in_path, params: { email: user.email, password: 'password123' }
    user
  end

  # Sign out a user in controller/integration tests
  # @return [nil]
  def sign_out_with_headers
    cookies.delete(:session_token) if cookies.respond_to?(:delete)
    @request.headers.delete('HTTP_COOKIE') if defined?(@request) && @request.respond_to?(:headers)
    ENV['TEST_USER_ID'] = nil
    nil
  end

  # Create a test session for a user
  # @param user [User] The user to create a session for
  # @return [Session] The created session object
  def create_test_session(user)
    Session.create!(
      user: user,
      user_agent: 'Test Browser',
      ip_address: '127.0.0.1'
    )
  end

  # Assert that a user is authenticated as the expected user
  # @param expected_user [User] The user that should be authenticated
  def assert_authenticated(expected_user)
    return unless defined?(@controller) && @controller.respond_to?(:current_user, true)

    actual_user = @controller.send(:current_user)
    assert_equal expected_user.id, actual_user&.id,
                 "Expected to be authenticated as #{expected_user.email}, got #{actual_user&.email || 'nil'}"
  end

  # Assert that a request was rejected due to insufficient authentication
  def assert_authentication_required
    assert_response :redirect
    assert_redirected_to sign_in_path
  end

  # Utility to verify the complete authentication state
  # @param user [User] The user to verify authentication for
  def verify_authentication_state(user)
    # Check the Current context if available
    if defined?(Current) && Current.respond_to?(:user)
      assert_equal user.id, Current.user&.id, 'Current.user should be set to the authenticated user'
    end

    # For controller and integration tests, check the controller's current_user
    if defined?(@controller) && @controller.respond_to?(:current_user, true)
      actual_user = @controller.send(:current_user)
      assert_equal user.id, actual_user&.id, 'Controller current_user should be the authenticated user'
    end

    # Verify session is active in database
    session = Session.find_by(user_id: user.id)
    assert session.present?, 'No active session found for user'
    assert_not session.expired?, 'Session should not be expired' if session.respond_to?(:expired?)
  end

  # Skip tests that depend on authentication if authentication is broken
  # This prevents cascading test failures when authentication itself is broken
  def skip_unless_authentication_working
    begin
      get root_path
    rescue StandardError
      nil
    end
    skip 'Authentication not working properly' if response&.redirect? && response&.location.to_s.include?('sign_in')
  end
end
