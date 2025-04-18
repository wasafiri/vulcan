# frozen_string_literal: true

require 'test_helper'

class VendorPortal::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    @vendor = Users::Vendor.find(users(:vendor_raz).id)
  end

  test "dashboard requires authentication" do
    # Access without logging in should redirect to sign in
    get vendor_dashboard_path
    assert_redirected_to sign_in_path
  end

  test "gets show when authenticated" do
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
