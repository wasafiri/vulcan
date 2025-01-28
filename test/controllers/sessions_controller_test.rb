require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user, password: "password123")
  end

  test "should get new" do
    get sign_in_path
    assert_response :success
  end

  test "should sign in" do
    post sign_in_path, params: { email: @user.email, password: "password123" }
    # Adjust expected redirect based on user role. For example, if @user is an Admin:
    assert_redirected_to admin_applications_path
    # Or, if it's a Constituent:
    # assert_redirected_to constituent_dashboard_path
  end

  test "should not sign in with wrong credentials" do
    post sign_in_path, params: { email: @user.email, password: "wrongpassword" }
    assert_redirected_to sign_in_path(email_hint: @user.email)
    follow_redirect!
    assert_match "Invalid email or password", flash[:alert]
  end
end
