require "test_helper"

class PasswordVisibilityIntegrationTest < ActionDispatch::IntegrationTest
  test "password visibility toggle works on sign in page" do
    get sign_in_path
    assert_response :success

    # Check that the toggle button exists with correct attributes
    assert_select "button[aria-label='Show password']"
    assert_select "button[aria-pressed='false']"
    assert_select "button.eye-closed"
  end

  test "password visibility toggle works on registration page" do
    get sign_up_path
    assert_response :success

    # Check that both password fields have toggle buttons
    assert_select "input#user_password + button[aria-label='Show password']"
    assert_select "input#user_password_confirmation + button[aria-label='Show password']"
  end

  test "password visibility toggle works on password reset page" do
    get new_password_path
    assert_response :success

    # Check that the toggle button exists
    assert_select "input[type='password'] + button[aria-label='Show password']"
  end

  test "password visibility toggle has correct accessibility attributes" do
    get sign_up_path
    assert_response :success

    # Check that the toggle button has the correct accessibility attributes
    assert_select "button[aria-label='Show password']" do |elements|
      elements.each do |element|
        assert_equal "false", element["aria-pressed"]
        assert element["class"].include?("eye-closed")
      end
    end
  end

  test "password visibility toggle has data-controller attribute" do
    get sign_up_path
    assert_response :success

    # Check that the toggle button has the correct data-controller attribute
    assert_select "div[data-controller='visibility']"
    assert_select "button[data-action*='visibility#toggle']"
  end

  test "password visibility toggle has timeout value" do
    get sign_up_path
    assert_response :success

    # Check that the toggle button has the correct data-visibility-timeout-value attribute
    assert_select "div[data-visibility-timeout-value]"
  end
end
