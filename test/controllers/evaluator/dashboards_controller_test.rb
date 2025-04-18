# frozen_string_literal: true

require 'test_helper'

module Evaluators
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @evaluator = create(:evaluator) # Using factory

      # Use the authentication helper from test_helper.rb
      post sign_in_path,
           params: { email: @evaluator.email, password: 'password123' },
           headers: { 'HTTP_USER_AGENT' => 'Rails Testing', 'REMOTE_ADDR' => '127.0.0.1' }

      assert_response :redirect
      follow_redirect!
    end

    def test_should_get_show
      get evaluators_dashboard_path
      assert_response :success
    end
  end
end
