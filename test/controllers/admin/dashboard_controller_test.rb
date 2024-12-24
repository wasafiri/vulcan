require "test_helper"

describe Admin::DashboardController do
  it "gets index" do
    get admin_dashboard_index_url
    must_respond_with :success
  end
end
