# frozen_string_literal: true

require 'test_helper'

class VendorPortal::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @vendor = create(:vendor)
    # Ensure no authentication state from previous tests
    Current.test_user_id = nil
    ENV['TEST_USER_ID'] = nil
    # Clear cookies that might contain session tokens
    cookies.delete(:session_token)
  end

  teardown do
    # Clean up authentication state after each test
    Current.test_user_id = nil
    ENV['TEST_USER_ID'] = nil
    cookies.delete(:session_token)
  end

  test 'dashboard requires authentication' do
    # Explicitly ensure no user is signed in
    Current.test_user_id = nil
    ENV['TEST_USER_ID'] = nil
    # Clear any cookies that might authenticate the user
    cookies.delete(:session_token)

    # Access without logging in should redirect to sign in
    get vendor_dashboard_path
    assert_redirected_to sign_in_path
  end

  test 'gets show when authenticated' do
    # Stub the authentication method to bypass full authentication flow
    ENV['TEST_USER_ID'] = @vendor.id.to_s

    # Create a session for the user (this is what sign_in helper would do)
    session = @vendor.sessions.create!(
      user_agent: 'Rails Testing',
      ip_address: '127.0.0.1'
    )

    # Set the cookie directly
    cookies[:session_token] = session.session_token

    get vendor_dashboard_path
    assert_response :success
  end
end
