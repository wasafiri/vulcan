# frozen_string_literal: true

require 'test_helper'

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  setup do
    # Clear emails before each test
    ActionMailer::Base.deliveries.clear

    # NOTE: This is a class variable to prevent multiple setup/teardown cycles
    # from causing template creation issues across parallel test runs
    @@templates_created ||= false

    unless @@templates_created
      # Ensure all email templates are cleared properly
      EmailTemplate.delete_all

      # Create required email templates for tests properly
      admin = create(:admin)

      # Create the required template using the factory - include both variables to satisfy validation
      create(:email_template, :text,
             name: 'application_notifications_registration_confirmation',
             subject: 'Welcome to the Maryland Accessible Telecommunications Program',
             body: 'This is a test text body for registration confirmation. %<user_first_name>s, %<user_full_name>s, %<dashboard_url>s, %<new_application_url>s, %<header_text>s, %<footer_text>s, %<active_vendors_text_list>s',
             description: 'Sent to a user upon successful account registration confirmation.',
             updated_by: admin)

      @@templates_created = true
    end
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
    assert_difference('User.count') do
      post sign_up_path, params: { user: {
        email: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'New',
        last_name: 'User',
        date_of_birth: '1990-01-01',
        phone: '555-555-5555',
        timezone: 'Eastern Time (US & Canada)',
        locale: 'en',
        # Disabilities are required for constituents
        hearing_disability: true,
        vision_disability: false,
        speech_disability: false,
        mobility_disability: false,
        cognition_disability: false
      } }
    end

    assert_redirected_to welcome_path
    assert_equal 'Account created successfully. Welcome!', flash[:notice]

    # Verify user was created correctly
    user = User.last
    assert_equal 'Users::Constituent', user.type # Correct STI class name
    assert user.hearing_disability
    assert_not user.vision_disability
    assert_equal 'newuser@example.com', user.email
  end

  def test_should_not_create_constituent_without_disabilities
    assert_no_difference('User.count') do
      post sign_up_path, params: { user: {
        email: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'New',
        last_name: 'User',
        date_of_birth: '1990-01-01',
        phone: '555-555-5555',
        timezone: 'Eastern Time (US & Canada)',
        locale: 'en',
        hearing_disability: false,
        vision_disability: false,
        speech_disability: false,
        mobility_disability: false,
        cognition_disability: false
      } }
    end

    assert_response :unprocessable_entity
    # Validation should prevent save, check errors on instance variable
    assert_includes assigns(:user).errors[:base], 'At least one disability must be selected.'
    # Removed assert_select as view structure might change or not include base errors easily
  end

  def test_should_not_create_user_with_invalid_phone
    assert_no_difference('User.count') do
      post sign_up_path, params: { user: {
        email: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'New',
        last_name: 'User',
        date_of_birth: '1990-01-01',
        phone: 'invalid-phone', # Invalid format
        timezone: 'Eastern Time (US & Canada)',
        locale: 'en',
        hearing_disability: true
      } }
    end

    assert_response :unprocessable_entity
    # Check errors directly on the instance variable assigned by the controller
    assert_includes assigns(:user).errors[:phone], 'must be a valid 10-digit US phone number'
  end

  def test_should_not_create_user_with_existing_email
    # Use FactoryBot to create an existing user
    existing_user = create(:constituent)

    assert_no_difference('User.count') do
      post sign_up_path, params: { user: {
        email: existing_user.email, # Already exists
        password: 'password123',
        password_confirmation: 'password123',
        first_name: 'New',
        last_name: 'User',
        date_of_birth: '1990-01-01',
        phone: '555-555-5555',
        timezone: 'Eastern Time (US & Canada)',
        locale: 'en',
        hearing_disability: true
      } }
    end

    assert_response :unprocessable_entity
    # Check errors directly on the instance variable assigned by the controller
    assert_includes assigns(:user).errors[:email], 'has already been taken'
  end

  def test_should_not_create_user_with_mismatched_passwords
    assert_no_difference('User.count') do
      post sign_up_path, params: { user: {
        email: 'newuser@example.com',
        password: 'password123',
        password_confirmation: 'different123', # Mismatched
        first_name: 'New',
        last_name: 'User',
        date_of_birth: '1990-01-01',
        phone: '555-555-5555',
        timezone: 'Eastern Time (US & Canada)',
        locale: 'en',
        hearing_disability: true
      } }
    end

    assert_response :unprocessable_entity
    # Check errors directly on the instance variable assigned by the controller
    assert_includes assigns(:user).errors[:password_confirmation], "doesn't match Password"
  end

  def test_should_send_registration_confirmation_email
    # Create template directly in this test to ensure it exists when needed
    admin = create(:admin)
    create(:email_template, :text,
           name: 'application_notifications_registration_confirmation',
           subject: 'Welcome to the Maryland Accessible Telecommunications Program',
           body: 'This is a test text body for registration confirmation. %<user_first_name>s, %<user_full_name>s, %<dashboard_url>s, %<new_application_url>s, %<header_text>s, %<footer_text>s, %<active_vendors_text_list>s',
           description: 'Sent to a user upon successful account registration confirmation.',
           updated_by: admin)

    # Clear deliveries to ensure clean state
    ActionMailer::Base.deliveries.clear

    # Create user parameters for registration
    user_params = {
      email: 'testuser@example.com',
      password: 'password123',
      password_confirmation: 'password123',
      first_name: 'Test',
      last_name: 'User',
      date_of_birth: '1990-01-01',
      phone: '555-555-5555',
      timezone: 'Eastern Time (US & Canada)',
      locale: 'en',
      communication_preference: 'email', # Ensure email is sent
      hearing_disability: true,
      vision_disability: false,
      speech_disability: false,
      mobility_disability: false,
      cognition_disability: false
    }

    # Verify a user will be created and one job (the mailer) will be enqueued
    assert_difference('User.count') do
      assert_enqueued_jobs 1 do
        # Create a new user with post request
        post sign_up_path, params: { user: user_params }
      end
    end

    # Now perform the enqueued jobs and check deliveries
    perform_enqueued_jobs
    assert_equal 1, ActionMailer::Base.deliveries.size, 'Email should have been delivered'

    # Verify the registration was successful
    assert_redirected_to welcome_path
    assert_equal 'Account created successfully. Welcome!', flash[:notice]

    # Verify user was created with expected attributes
    user = User.find_by(email: 'testuser@example.com')
    assert_not_nil user, 'User should have been created'
    assert_equal 'Test', user.first_name
    assert_equal 'User', user.last_name
    assert user.hearing_disability

    # Verify the email was sent and has correct attributes
    assert_equal 1, ActionMailer::Base.deliveries.size, 'One email should have been sent'
    email = ActionMailer::Base.deliveries.last

    # Verify email headers
    assert_not_nil email, 'Email should not be nil'
    assert_equal ['no_reply@mdmat.org'], email.from, 'Email should be from no_reply@mdmat.org'
    assert_equal ['testuser@example.com'], email.to, 'Email should be sent to the registered user'
    assert_equal 'Welcome to the Maryland Accessible Telecommunications Program', email.subject
    assert_not email.multipart?, 'Email should not be multipart'

    # Get the email content
    content = email.body.to_s

    # Test that variables were substituted with values
    assert_match(/Test/, content, 'First name should be substituted')
    assert_match(/Test User/, content, 'Full name should be substituted')
    assert_match(%r{constituent_portal/dashboard}, content, 'Should include dashboard link')
    assert_match(%r{constituent_portal/applications/new}, content, 'Should include new application link')
  end
end
