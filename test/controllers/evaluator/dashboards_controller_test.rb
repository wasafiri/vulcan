require "test_helper"

class Evaluator::DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "gets show" do
    get evaluator_dashboard_show_url
    assert_response :success
  end
end
