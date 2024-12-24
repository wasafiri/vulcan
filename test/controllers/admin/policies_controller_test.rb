require "test_helper"

describe Admin::PoliciesController do
  it "gets edit" do
    get admin_policies_edit_url
    must_respond_with :success
  end

  it "gets update" do
    get admin_policies_update_url
    must_respond_with :success
  end
end
