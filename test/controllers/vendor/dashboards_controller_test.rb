require "test_helper"

class Vendor::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @vendor = create(:vendor)
    sign_in(@vendor)
  end

  test "gets show" do
    get vendor_dashboard_path
    assert_response :success
  end
end
