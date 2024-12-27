require "test_helper"

class Admin::ApplicationsControllerTest < ActionDispatch::IntegrationTest
 setup do
   @application = applications(:one) # Add fixture or factory
   @admin = users(:admin) # Add fixture or factory
   sign_in_as(@admin)
 end

 test "should get index" do
   get admin_applications_path
   assert_response :success
 end

 test "should get show" do
   get admin_application_path(@application)
   assert_response :success
 end

 test "should get edit" do
   get edit_admin_application_path(@application)
   assert_response :success
 end

 test "should update application" do
   patch admin_application_path(@application), params: { application: { status: "approved" } }
   assert_redirected_to admin_application_path(@application)
 end

 test "should search applications" do
   get search_admin_applications_path, params: { q: "test" }
   assert_response :success
 end

 test "should filter applications" do
   get filter_admin_applications_path, params: { status: "pending" }
   assert_response :success
 end

 test "should batch approve applications" do
   post batch_approve_admin_applications_path, params: { ids: [ @application.id ] }
   assert_redirected_to admin_applications_path
 end

 test "should batch reject applications" do
   post batch_reject_admin_applications_path, params: { ids: [ @application.id ] }
   assert_redirected_to admin_applications_path
 end

 test "should verify income" do
   patch verify_income_admin_application_path(@application)
   assert_redirected_to admin_application_path(@application)
 end

 test "should request documents" do
   patch request_documents_admin_application_path(@application)
   assert_redirected_to admin_application_path(@application)
 end
end
