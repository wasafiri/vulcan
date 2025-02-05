require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:constituent_john)  # Use fixture instead of factory
    @original_password_digest = @user.password_digest
    sign_in(@user)  # Use standard sign_in helper from test_helper
  end

  def test_should_get_edit
    get edit_password_path
    assert_response :success
    assert_select "form[action=?]", password_path
  end

  def test_should_update_password_with_valid_inputs
    patch password_path, params: {
      password_challenge: "password123",  # Use fixture password
      password: "NewValid*Password123",
      password_confirmation: "NewValid*Password123"
    }

    assert_redirected_to sign_in_path
    follow_redirect!
    assert_equal "Password successfully updated", flash[:notice]

    # Verify password was actually changed
    @user.reload
    assert_not_equal @original_password_digest, @user.password_digest
  end

  def test_should_not_update_password_with_wrong_current_password
    patch password_path, params: {
      password_challenge: "wrongpassword",
      password: "NewValid*Password123",
      password_confirmation: "NewValid*Password123"
    }

    assert_response :unprocessable_entity
    assert_select "div.alert", /Current password is incorrect/

    # Verify password was not changed
    @user.reload
    assert_equal @original_password_digest, @user.password_digest
  end

  def test_should_not_update_password_with_mismatched_confirmation
    patch password_path, params: {
      password_challenge: "password123",
      password: "NewValid*Password123",
      password_confirmation: "DifferentPassword123"
    }

    assert_response :unprocessable_entity
    assert_select "div.alert", /New password and confirmation don't match/

    # Verify password was not changed
    @user.reload
    assert_equal @original_password_digest, @user.password_digest
  end

  def test_should_not_update_password_with_invalid_new_password
    patch password_path, params: {
      password_challenge: "password123",
      password: "short",
      password_confirmation: "short"
    }

    assert_response :unprocessable_entity
    assert_select "div.alert", /Password is too short/

    # Verify password was not changed
    @user.reload
    assert_equal @original_password_digest, @user.password_digest
  end
end
