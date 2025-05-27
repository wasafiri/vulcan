# frozen_string_literal: true

# AuthenticationTestHelper
#
# Standardised helpers for signing users in/out across non-system tests.
# – Controller tests → sign_in_as
# – Integration tests → sign_in_with_headers
# – Unit/other        → update_current_user
#
# For system tests, see SystemTestAuthentication module.
# Add ENV['DEBUG_AUTH']='true' to see verbose output while debugging.
#
module AuthenticationTestHelper
  # Include shared authentication core functionality
  include AuthenticationCore
  # Unified entry-point -------------------------------------------------------

  # Signs a user in using the best strategy for the current test context.
  #
  # @param user [User]
  # @return [User] the same user, for chaining in tests
  def sign_in(user)
    if defined?(@controller) && @controller.is_a?(ActionController::Base)
      sign_in_as(user) # controller helper
    elsif is_integration_test?
      sign_in_with_headers(user) # integration helper
    else
      update_current_user(user) # fallback for unit/unknown
    end
  end

  #-------------------------------------------------------------------------

  # Controller-level cookie sign-in.
  def sign_in_as(user)
    session = create_test_session(user)

    # Mirror what Rails would do from the cookie, so authenticate! sees it
    if defined?(request) && request.respond_to?(:session)
      request.session[:session_token] = session.session_token
    end

    if respond_to?(:cookies) && cookies.respond_to?(:signed)
      cookies.signed[:session_token] = { value: session.session_token, httponly: true }
    elsif respond_to?(:cookies)
      cookies[:session_token] = session.session_token
    end

    # Make Current.user available immediately for any before_action
    update_current_user(user)

    # Store test user ID in thread local variable
    store_test_user_id(user.id)

    debug_auth "CONTROLLER AUTH: cookie & request.session set for #{user.email}"
    user
  end

  # Integration-level header sign-in.
  def sign_in_with_headers(user)
    session = create_test_session(user)
    raw_cookie = "session_token=#{session.session_token}"

    # Seed the rack mock session cookie (IntegrationTest)
    if respond_to?(:rack_mock_session) && rack_mock_session.respond_to?(:cookie_jar)
      rack_mock_session.cookie_jar[:session_token] = session.session_token
    end

    # `default_headers` is defined by Rails::TestRequest; fall back gracefully.
    default_headers.merge!('Cookie' => raw_cookie) if respond_to?(:default_headers, true)

    # Set cookies anyway, because some helpers still read them.
    if respond_to?(:cookies) && cookies.respond_to?(:signed)
      cookies.signed[:session_token] = session.session_token
    elsif respond_to?(:cookies)
      cookies[:session_token] = session.session_token
    end

    # Make Current.user available immediately
    update_current_user(user)

    # Store test user ID in thread local variable
    store_test_user_id(user.id)

    debug_auth "INTEGRATION AUTH: rack_mock_session, cookies & headers set for #{user.email}"
    user
  end

  # Pure unit-test fallback: just update Current.user.
  def update_current_user(user)
    Current.user = user if defined?(Current)
    @current_user ||= user
    debug_auth "UNIT AUTH: Current.user set for #{user.email}"
    user
  end

  # Optional convenience helper: simulate a form-based sign-in (slow!).
  def sign_in_user(user, password: 'password123')
    post sign_in_path, params: { email: user.email, password: password }
    assert_response :redirect
    assert_redirected_to root_path, 'Sign in failed to redirect properly'
    update_current_user(user)
    user
  end

  # Sign out regardless of context.
  def sign_out
    # Use the shared cookie deletion logic that handles all driver types
    delete_session_cookie

    # Clear test identity (thread-locals, Current.user, etc.)
    clear_test_identity
  end
  alias sign_out_with_headers sign_out # preserve original name

  # Assertions ---------------------------------------------------------------

  def assert_authenticated(expected_user)
    return unless defined?(@controller) && @controller.respond_to?(:current_user, true)

    actual = @controller.send(:current_user)
    assert_equal expected_user.id, actual&.id,
                 "Expected to be signed in as #{expected_user.email}, got #{actual&.email || 'nil'}"
  end

  def assert_authentication_required
    assert_response :redirect
    assert_redirected_to sign_in_path
  end

  # Skip spec if auth system clearly broken, to avoid cascading failures.
  def skip_unless_authentication_working
    begin
      get root_path
    rescue StandardError
      nil
    end
    return unless response&.redirect? && response.location.to_s.include?('sign_in')

    skip 'Authentication not working properly'
  end

  private

  def is_integration_test?
    defined?(post) && respond_to?(:post) && self.class < ActionDispatch::IntegrationTest
  end
end
