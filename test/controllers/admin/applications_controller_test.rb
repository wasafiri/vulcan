# test/controllers/admin/applications_controller_test.rb
require "test_helper"

class Admin::ApplicationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create and log in as an admin user
    @admin = FactoryBot.create(:admin, password: "password123")
    post sign_in_path, params: { email: @admin.email, password: "password123" }
    assert_redirected_to root_path # Adjust if necessary
    follow_redirect!
    assert_response :success

    # Create an application to use in tests
    @application = FactoryBot.create(:application)
  end

  test "should get index" do
    get admin_applications_path
    assert_response :success
    # Additional assertions...
  end

  test "should get show" do
    get admin_application_path(@application)
    assert_response :success
    # Additional assertions...
  end

  test "should get edit" do
    get edit_admin_application_path(@application)
    assert_response :success
    # Additional assertions...
  end

  test "should update application" do
    patch admin_application_path(@application), params: { application: { status: "approved" } }
    assert_redirected_to admin_application_path(@application)
    follow_redirect!
    assert_response :success
    assert_equal "Application updated.", flash[:notice]
  end

  test "should batch approve applications" do
    application2 = FactoryBot.create(:application)
    post batch_approve_admin_applications_path, params: { ids: [ @application.id, application2.id ] }
    assert_redirected_to admin_applications_path
    follow_redirect!
    assert_response :success
    assert_equal "Applications approved.", flash[:notice]
    assert @application.reload.approved?
    assert application2.reload.approved?
  end

  test "should batch reject applications" do
    application2 = FactoryBot.create(:application)
    post batch_reject_admin_applications_path, params: { ids: [ @application.id, application2.id ] }
    assert_redirected_to admin_applications_path
    follow_redirect!
    assert_response :success
    assert_equal "Applications rejected.", flash[:notice]
    assert @application.reload.rejected?
    assert application2.reload.rejected?
  end

  test "should search applications" do
    get search_admin_applications_path, params: { q: @application.user.last_name }
    assert_response :success
    # Additional assertions...
  end

  test "should filter applications" do
    get filter_admin_applications_path, params: { status: "approved" }
    assert_response :success
    # Additional assertions...
  end

  test "should request documents" do
    post request_documents_admin_application_path(@application)
    assert_redirected_to admin_application_path(@application)
    follow_redirect!
    assert_response :success
    assert_equal "Documents requested.", flash[:notice]
    assert @application.reload.awaiting_documents?
  end
end
