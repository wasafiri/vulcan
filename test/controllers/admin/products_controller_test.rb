require "test_helper"

describe Admin::ProductsController do
  it "gets index" do
    get admin_products_index_url
    must_respond_with :success
  end

  it "gets show" do
    get admin_products_show_url
    must_respond_with :success
  end

  it "gets new" do
    get admin_products_new_url
    must_respond_with :success
  end

  it "gets create" do
    get admin_products_create_url
    must_respond_with :success
  end

  it "gets edit" do
    get admin_products_edit_url
    must_respond_with :success
  end

  it "gets update" do
    get admin_products_update_url
    must_respond_with :success
  end

  it "gets archive" do
    get admin_products_archive_url
    must_respond_with :success
  end

  it "gets unarchive" do
    get admin_products_unarchive_url
    must_respond_with :success
  end
end
