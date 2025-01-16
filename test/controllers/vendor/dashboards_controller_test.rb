require "test_helper"

class Vendor::DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "gets show" do
    get vendor_dashboard_show_url
    assert_response :success
  end
end
