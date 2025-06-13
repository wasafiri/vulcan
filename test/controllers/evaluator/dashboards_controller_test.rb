# frozen_string_literal: true

require 'test_helper'

module Evaluators
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @evaluator = create(:evaluator) # Using factory

      # Use the correct sign-in helper for integration tests
      sign_in_for_integration_test(@evaluator)
    end

    def test_should_get_show
      get evaluators_dashboard_path
      assert_response :success
    end
  end
end
