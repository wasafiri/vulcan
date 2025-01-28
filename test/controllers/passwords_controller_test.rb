require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
    sign_in_as(@user)
  end

  test "should get edit" do
    get edit_password_path
    assert_response :success
  end

  test "should update password" do
    patch password_path, params: {
      password_challenge: "Secret1*3*5*",
      password: "Secret6*4*2*",
      password_confirmation: "Secret6*4*2*"
    }
    # Controller redirects to sign_in_path on success
    assert_redirected_to sign_in_path

    follow_redirect!
    # The controller sets flash[:notice] = "Password successfully updated"
    assert_equal "Password successfully updated", flash[:notice]
  end

  test "should not update password with wrong password challenge" do
    patch password_path, params: {
      password_challenge: "SecretWrong1*3",
      password: "Secret6*4*2*",
      password_confirmation: "Secret6*4*2*"
    }

    # The controller renders :edit with status 422 (unprocessable entity)
    assert_response :unprocessable_entity

    # The controller sets flash.now[:alert] = "Current password is incorrect"
    # We can look for that in the response body or the flash. If your view
    # puts it in a <p> or similar element, this matches that usage:
    assert_select "p", /Current password is incorrect/
  end
end
