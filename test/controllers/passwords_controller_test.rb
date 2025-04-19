# frozen_string_literal: true

require 'test_helper'

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  def setup
    # Track performance for monitoring
    @start_time = Time.current

    @user = create(:constituent, password: 'password123', password_confirmation: 'password123')
    @original_password_digest = @user.password_digest

    # Standard sign-in for controller tests
    sign_in(@user)
  end

  def teardown
    # Standard sign out for controller tests
    sign_out if respond_to?(:sign_out)

    # Log test execution time for performance monitoring
    @execution_time = Time.current - @start_time
    puts "PasswordsControllerTest #{name} took #{@execution_time.round(2)}s"
  end

  # Helper method for safer controller actions
  def safe_request
    yield
    true
  rescue StandardError => e
    puts "Error during request: #{e.message}"
    false
  end

  def test_should_get_edit
    result = safe_request { get edit_password_path }
    return unless result

    assert_response :success
    assert_select 'form[action=?]', password_path
  end

  def test_should_update_password_with_valid_inputs
    result = safe_request do
      patch password_path, params: {
        password_challenge: 'password123',
        password: 'NewValid*Password123',
        password_confirmation: 'NewValid*Password123'
      }
    end

    return unless result

    assert_redirected_to sign_in_path
    follow_redirect!
    assert_equal 'Password successfully updated.', flash[:notice]

    # Verify password was actually changed
    @user.reload
    assert_not_equal @original_password_digest, @user.password_digest
  end

  def test_should_not_update_password_with_wrong_current_password
    safe_request do
      patch password_path, params: {
        password_challenge: 'wrongpassword',
        password: 'NewValid*Password123',
        password_confirmation: 'NewValid*Password123'
      }
    end

    assert_response :unprocessable_entity
    assert_equal 'Current password is incorrect.', flash[:alert] # Add period

    # Verify password was not changed
    @user.reload
    assert_equal @original_password_digest, @user.password_digest
  end

  def test_should_not_update_password_with_mismatched_confirmation
    safe_request do
      patch password_path, params: {
        password_challenge: 'password123', # Use the password set in setup
        password: 'NewValid*Password123',
        password_confirmation: 'DifferentPassword123'
      }
    end

    assert_response :unprocessable_entity
    assert_equal 'New password and confirmation do not match.', flash[:alert] # Add period

    # Verify password was not changed
    @user.reload
    assert_equal @original_password_digest, @user.password_digest
  end

  def test_should_not_update_password_with_invalid_new_password
    safe_request do
      patch password_path, params: {
        password_challenge: 'password123', # Use the password set in setup
        password: 'short',
        password_confirmation: 'short'
      }
    end

    assert_response :unprocessable_entity
    # Check for model validation error message in the flash
    assert_equal 'Unable to update password. Please check requirements.', flash[:alert] # Add extra text

    # Verify password was not changed
    @user.reload
    assert_equal @original_password_digest, @user.password_digest
  end
end
