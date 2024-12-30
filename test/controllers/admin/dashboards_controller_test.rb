require "test_helper"

class Admin::DashboardsControllerTest < ActionDispatch::IntegrationTest
 setup do
   @admin = users(:admin) # Add fixture/factory
   sign_in_as(@admin)
 end

 test "should get index" do
   get admin_root_path
   assert_response :success
 end
end
