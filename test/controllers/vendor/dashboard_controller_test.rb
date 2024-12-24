require "test_helper"

describe Vendor::DashboardController do
  it "gets show" do
    get vendor_dashboard_show_url
    must_respond_with :success
  end
end
