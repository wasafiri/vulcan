require "test_helper"

describe Admin::ApplicationsController do
  it "gets index" do
    get admin_applications_index_url
    must_respond_with :success
  end

  it "gets show" do
    get admin_applications_show_url
    must_respond_with :success
  end

  it "gets edit" do
    get admin_applications_edit_url
    must_respond_with :success
  end

  it "gets update" do
    get admin_applications_update_url
    must_respond_with :success
  end

  it "gets search" do
    get admin_applications_search_url
    must_respond_with :success
  end

  it "gets filter" do
    get admin_applications_filter_url
    must_respond_with :success
  end

  it "gets batch_approve" do
    get admin_applications_batch_approve_url
    must_respond_with :success
  end

  it "gets batch_reject" do
    get admin_applications_batch_reject_url
    must_respond_with :success
  end

  it "gets verify_income" do
    get admin_applications_verify_income_url
    must_respond_with :success
  end

  it "gets request_documents" do
    get admin_applications_request_documents_url
    must_respond_with :success
  end
end
