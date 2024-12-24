require "test_helper"

describe Admin::UsersController do
  it "gets index" do
    get admin_users_index_url
    must_respond_with :success
  end

  it "gets show" do
    get admin_users_show_url
    must_respond_with :success
  end

  it "gets edit" do
    get admin_users_edit_url
    must_respond_with :success
  end

  it "gets update" do
    get admin_users_update_url
    must_respond_with :success
  end
end
