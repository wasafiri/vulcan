# frozen_string_literal: true

require 'test_helper'

module VendorPortal
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    setup do
      @vendor = create(:vendor)
      # Ensure a clean authentication state before each test
      Current.test_user_id = nil
      ENV['TEST_USER_ID'] = nil
      cookies.delete(:session_token)
      # Explicitly clear any authenticated user set by helpers
      @authenticated_user = nil
    end

    teardown do
      # Clean up authentication state after each test
      Current.test_user_id = nil
      ENV['TEST_USER_ID'] = nil
      cookies.delete(:session_token)
      # Explicitly reset the session to prevent state leakage
      reset!
    end

    test 'dashboard requires authentication' do
      # Ensure a completely unauthenticated state for this specific test
      sign_out # Use the sign_out helper to ensure no user is authenticated
      Current.test_user_id = nil
      ENV['TEST_USER_ID'] = nil
      cookies.delete(:session_token)
      reset! # Explicitly reset the session

      # Access without logging in should redirect
      get vendor_portal_dashboard_path
      assert_response :redirect
      # Could redirect to sign_in_path or root_path depending on authentication flow
    end

    test 'gets show when authenticated' do
      sign_in_with_headers(@vendor)
      get vendor_portal_dashboard_path
      assert_response :success
    end
  end
end
