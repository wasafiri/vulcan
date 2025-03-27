# frozen_string_literal: true

require 'test_helper'

module Admin
  class DashboardsControllerTest < ActionDispatch::IntegrationTest
    def test_should_get_index
      sign_in users(:admin_david)
      get admin_root_path
      assert_response :success
    end
  end
end
