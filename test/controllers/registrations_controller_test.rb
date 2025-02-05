require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def test_should_get_new
    get sign_up_path
    assert_response :success
  end

  def test_should_create_constituent_with_required_fields
    assert_difference("User.count") do
      post sign_up_path, params: { user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "New",
        last_name: "User",
        date_of_birth: "1990-01-01",
        phone: "555-555-5555",
        timezone: "Eastern Time (US & Canada)",
        locale: "en",
        # Disabilities are required for constituents
        hearing_disability: true,
        vision_disability: false,
        speech_disability: false,
        mobility_disability: false,
        cognition_disability: false
      } }
    end

    assert_redirected_to root_path
    assert_equal "Account created successfully. Welcome!", flash[:notice]

    # Verify user was created correctly
    user = User.last
    assert_equal "Constituent", user.type
    assert user.hearing_disability
    assert_not user.vision_disability
    assert_equal "newuser@example.com", user.email
  end

  def test_should_not_create_constituent_without_disabilities
    assert_no_difference("User.count") do
      post sign_up_path, params: { user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "New",
        last_name: "User",
        date_of_birth: "1990-01-01",
        phone: "555-555-5555",
        timezone: "Eastern Time (US & Canada)",
        locale: "en",
        hearing_disability: false,
        vision_disability: false,
        speech_disability: false,
        mobility_disability: false,
        cognition_disability: false
      } }
    end

    assert_response :unprocessable_entity
    assert_select "div#error_explanation" # Adjust based on your view's error handling
    assert_select "li", "At least one disability must be selected."
  end

  def test_should_not_create_user_with_invalid_phone
    assert_no_difference("User.count") do
      post sign_up_path, params: { user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "password123",
        first_name: "New",
        last_name: "User",
        date_of_birth: "1990-01-01",
        phone: "invalid-phone",  # Invalid format
        timezone: "Eastern Time (US & Canada)",
        locale: "en",
        hearing_disability: true
      } }
    end

    assert_response :unprocessable_entity
    assert_select "li", "Phone must be in format XXX-XXX-XXXX"
  end


  def test_should_not_create_user_with_existing_email
    existing_user = users(:constituent_john)

    assert_no_difference("User.count") do
      post sign_up_path, params: { user: {
        email: existing_user.email,  # Already exists
        password: "password123",
        password_confirmation: "password123",
        first_name: "New",
        last_name: "User",
        date_of_birth: "1990-01-01",
        phone: "555-555-5555",
        timezone: "Eastern Time (US & Canada)",
        locale: "en",
        hearing_disability: true
      } }
    end

    assert_response :unprocessable_entity
    assert_includes User.last.errors.full_messages,
                    "Email has already been taken"
  end

  def test_should_not_create_user_with_mismatched_passwords
    assert_no_difference("User.count") do
      post sign_up_path, params: { user: {
        email: "newuser@example.com",
        password: "password123",
        password_confirmation: "different123",  # Mismatched
        first_name: "New",
        last_name: "User",
        date_of_birth: "1990-01-01",
        phone: "555-555-5555",
        timezone: "Eastern Time (US & Canada)",
        locale: "en",
        hearing_disability: true
      } }
    end

    assert_response :unprocessable_entity
    assert_includes User.last.errors.full_messages,
                    "Password confirmation doesn't match Password"
  end
end
