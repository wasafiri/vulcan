require "test_helper"

class Admin::PoliciesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create(:admin)
    sign_in(@admin) # Use the sign_in method from test_helper.rb
    @policy = create(:policy) # Ensure you have a Policy factory
  end

  test "should get edit" do
    get admin_policies_path(@policy)
    assert_response :success
  end

  test "should update policy" do
    patch admin_policies_path(@policy), params: { policy: { name: "New Policy Name" } }
    assert_redirected_to admin_policies_path(@policy)
  end
end
