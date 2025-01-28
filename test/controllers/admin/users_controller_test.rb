require "test_helper"

class Admin::ReportsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create(:admin)
    sign_in_as(@admin)
  end

  test "should get index" do
    get admin_reports_path
    assert_response :success
  end

  test "should get show" do
    @report = create(:report) # Ensure a report factory is available
    get admin_report_path(@report)
    assert_response :success
  end

  test "should get equipment distribution" do
    get equipment_distribution_admin_reports_path
    assert_response :success
  end

  test "should get evaluation metrics" do
    get evaluation_metrics_admin_reports_path
    assert_response :success
  end

  test "should get vendor performance" do
    get vendor_performance_admin_reports_path
    assert_response :success
  end
end
