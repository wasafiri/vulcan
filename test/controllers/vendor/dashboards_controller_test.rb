require "test_helper"

describe Vendor::DashboardsController do
  it "gets show" do
    get vendor_dashboard_show_url
    must_respond_with :success
  end
end
