require "test_helper"

class Admin::PoliciesControllerTest < ActionDispatch::IntegrationTest
 setup do
   @admin = users(:admin)
   sign_in_as(@admin)
   @policy = policies(:one)
 end

 test "should get edit" do
   get edit_admin_policies_path
   assert_response :success
 end

 test "should update policy" do
   patch admin_policies_path, params: { policies: { @policy.id => { value: 5 } } }
   assert_redirected_to edit_admin_policies_path
 end
end
