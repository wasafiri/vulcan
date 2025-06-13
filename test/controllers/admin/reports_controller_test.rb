# frozen_string_literal: true

require 'test_helper'

module Admin
  class ReportsControllerTest < ActionDispatch::IntegrationTest
    def setup
      # Create an admin user with FactoryBot
      @admin = create(:admin)

      # Set standard test headers
      @headers = {
        'HTTP_USER_AGENT' => 'Rails Testing',
        'REMOTE_ADDR' => '127.0.0.1'
      }

      # Use the sign_in helper from test_helper.rb
      sign_in_for_integration_test(@admin)
    end

    def test_should_get_index
      get admin_reports_path
      assert_response :success
    end
  end
end
