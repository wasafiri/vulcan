require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get sign_up_path
    assert_response :success
  end

  test "should sign up" do
    assert_difference("User.count", 1) do
      post sign_up_path, params: { user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "New",
        last_name: "User",
        date_of_birth: "1990-01-01",
        phone: "555-555-5555",
        timezone: "Eastern Time (US & Canada)",
        locale: "en"
        # Add any other required fields here
      } }
    end
    assert_redirected_to root_path
  end
end
