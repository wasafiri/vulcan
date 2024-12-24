require "test_helper"

describe Admin::ReportsController do
  it "gets index" do
    get admin_reports_index_url
    must_respond_with :success
  end

  it "gets show" do
    get admin_reports_show_url
    must_respond_with :success
  end

  it "gets equipment_distribution" do
    get admin_reports_equipment_distribution_url
    must_respond_with :success
  end

  it "gets evaluation_metrics" do
    get admin_reports_evaluation_metrics_url
    must_respond_with :success
  end

  it "gets vendor_performance" do
    get admin_reports_vendor_performance_url
    must_respond_with :success
  end
end
