require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  setup do
    # Clear emails before each test
    ActionMailer::Base.deliveries.clear
  end
  
  teardown do
    # Clean up after tests
    ActionMailer::Base.deliveries.clear
  end
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
  
  def test_should_send_registration_confirmation_email
    # Create user parameters for registration
    user_params = {
      email: "testuser@example.com",
      password: "password123",
      password_confirmation: "password123",
      first_name: "Test",
      last_name: "User",
      date_of_birth: "1990-01-01",
      phone: "555-555-5555",
      timezone: "Eastern Time (US & Canada)",
      locale: "en",
      hearing_disability: true,
      vision_disability: false,
      speech_disability: false,
      mobility_disability: false,
      cognition_disability: false
    }
    
    # Verify an email will be delivered and a user will be created
    assert_changes -> { ActionMailer::Base.deliveries.count }, from: 0, to: 1 do
      assert_difference("User.count") do
        perform_enqueued_jobs do
          # Create a new user with post request
          post sign_up_path, params: { user: user_params }
        end
      end
    end

    # Verify the registration was successful
    assert_redirected_to root_path
    assert_equal "Account created successfully. Welcome!", flash[:notice]
    
    # Verify user was created with expected attributes
    user = User.find_by(email: "testuser@example.com")
    assert_not_nil user, "User should have been created"
    assert_equal "Test", user.first_name
    assert_equal "User", user.last_name
    assert user.hearing_disability
    
    # Verify the email was sent and has correct attributes
    assert_equal 1, ActionMailer::Base.deliveries.size, "One email should have been sent"
    email = ActionMailer::Base.deliveries.last
    
    # Verify email headers
    assert_not_nil email, "Email should not be nil"
    assert_equal ["no_reply@mdmat.org"], email.from, "Email should be from no_reply@mdmat.org"
    assert_equal ["testuser@example.com"], email.to, "Email should be sent to the registered user"
    assert_equal "Welcome to the Maryland Accessible Telecommunications Program", email.subject
    
    # Verify email is multipart (HTML and text)
    assert email.multipart?, "Email should be multipart"
    assert_equal 2, email.parts.size, "Email should have HTML and text parts"
    
    # Verify HTML part exists and has correct content
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_not_nil html_part, "HTML part should exist"
    html_content = html_part.body.to_s
    
    # Check for key elements in HTML content
    assert_match(/Dear Test,/, html_content, "Should include personalized greeting")
    assert_match(/Program Overview/, html_content, "Should include program overview heading")
    assert_match(/Next Steps/, html_content, "Should include next steps heading")
    assert_match(/Available Products/, html_content, "Should include available products section")
    
    # Verify links are included
    assert_match(/dashboard/, html_content, "Should include dashboard link")
    assert_match(/new application/, html_content, "Should include application link")
    
    # Verify text part exists and has correct content
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_not_nil text_part, "Text part should exist"
    text_content = text_part.body.to_s
    
    # Check for key elements in text content
    assert_match(/Dear Test,/, text_content, "Should include personalized greeting")
    assert_match(/PROGRAM OVERVIEW/, text_content, "Should include program overview section")
    assert_match(/NEXT STEPS/, text_content, "Should include next steps section")
    assert_match(/AVAILABLE PRODUCTS/, text_content, "Should include available products section")
  end
end
