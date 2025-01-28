require "test_helper"

class Evaluator::DashboardsControllerTest < ActionDispatch::IntegrationTest
  test "gets show" do
    get evaluators_dashboard_path
    assert_response :success
  end
end
