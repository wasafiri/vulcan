require "test_helper"

class Admin::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create(:admin)
    sign_in(@admin) # Use sign_in instead of sign_in_as
  end

  test "should get index" do
    get admin_dashboard_path
    assert_response :success
  end
end
