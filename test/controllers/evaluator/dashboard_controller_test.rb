require "test_helper"

describe Evaluator::DashboardController do
  it "gets show" do
    get evaluator_dashboard_show_url
    must_respond_with :success
  end
end
