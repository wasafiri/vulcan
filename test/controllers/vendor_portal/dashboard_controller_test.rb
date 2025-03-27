# frozen_string_literal: true

require 'test_helper'

module VendorPortal
  class DashboardControllerTest < ActionDispatch::IntegrationTest
    def setup
      @vendor = users(:vendor_raz) # Use fixture instead of factory

      # Set standard test headers
      @headers = {
        'HTTP_USER_AGENT' => 'Rails Testing',
        'REMOTE_ADDR' => '127.0.0.1'
      }

      post sign_in_path,
           params: { email: @vendor.email, password: 'password123' },
           headers: @headers

      assert_response :redirect
      follow_redirect!
    end

    def test_get_show
      get vendor_portal_dashboard_path
      assert_response :success
      assert_not_nil assigns(:recent_vouchers)
      assert_not_nil assigns(:pending_vouchers)
      assert_not_nil assigns(:vendor_stats)
    end
  end
end
