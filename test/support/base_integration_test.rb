# frozen_string_literal: true

# Base Integration Test
#
# This class provides a common base for all integration tests that require
# authentication. It ensures that all tests use the same authentication approach
# and provides helper methods for common tasks.
class BaseIntegrationTest < ActionDispatch::IntegrationTest
  include AuthenticationTestHelper
  include FlashTestHelper
  include FormTestHelper

  setup do
    # Enable debug logging for authentication issues
    ENV["DEBUG_AUTH"] = "true"
  end

  # Helper method to sign in a user and verify authentication worked
  def sign_in_and_verify(user)
    # Sign in the user
    sign_in(user)

    # Debug output
    Rails.logger.debug "BASE TEST: After sign_in"
    Rails.logger.debug "BASE TEST: Cookies: #{cookies.inspect}"
    Rails.logger.debug "BASE TEST: Session token in cookies: #{cookies[:session_token]}"
    if cookies.respond_to?(:signed)
      Rails.logger.debug "BASE TEST: Signed session token: #{cookies.signed[:session_token]}"
    end

    # Verify cookie is set
    assert_not_nil cookies[:session_token], "Session token cookie not set"
    if cookies.respond_to?(:signed)
      assert_not_nil cookies.signed[:session_token], "Signed session token cookie not set"
    end

    # Verify we can access a protected page
    get constituent_portal_applications_path

    # Debug output
    Rails.logger.debug "BASE TEST: After accessing protected page"
    Rails.logger.debug "BASE TEST: Response status: #{response.status}"
    Rails.logger.debug "BASE TEST: Response location: #{response.location}" if response.redirect?

    # Verify we're not redirected to sign in
    assert_response :success, "Expected to access protected page, but was redirected to #{response.location}"

    # Return the user for method chaining
    user
  end

  # Helper method to verify that a user is authenticated
  def assert_authenticated
    # Verify we can access a protected page
    get constituent_portal_applications_path

    # Verify we're not redirected to sign in
    assert_response :success, "Expected to be authenticated, but was redirected to sign in"
  end

  # Helper method to verify that a user is not authenticated
  def assert_not_authenticated
    # Verify we can't access a protected page
    get constituent_portal_applications_path

    # Verify we're redirected to sign in
    assert_redirected_to sign_in_path, "Expected to be redirected to sign in, but was not"
  end

  # Helper method to verify that a flash message is present
  def assert_flash_message(type, message)
    assert_equal message, flash[type.to_sym], "Expected flash #{type} to be '#{message}', but was '#{flash[type.to_sym]}'"
  end

  # Helper method to verify that a flash message is not present
  def assert_no_flash_message(type)
    assert_nil flash[type.to_sym], "Expected no flash #{type}, but found '#{flash[type.to_sym]}'"
  end

  # Helper method to verify that a record was created
  def assert_record_created(model_class)
    assert_difference("#{model_class}.count", 1) do
      yield
    end
  end

  # Helper method to verify that a record was not created
  def assert_record_not_created(model_class)
    assert_no_difference("#{model_class}.count") do
      yield
    end
  end

  # Helper method to verify that a record was updated
  def assert_record_updated(record)
    record.reload
    yield(record)
  end

  # Helper method to verify that a record was not updated
  def assert_record_not_updated(record, attributes)
    original_values = attributes.transform_values { |attr| record.send(attr) }
    yield
    record.reload
    attributes.each do |attr, original_value|
      assert_equal original_value, record.send(attr), "Expected #{attr} not to change, but it did"
    end
  end

  # Helper method to verify that a record was deleted
  def assert_record_deleted(model_class)
    assert_difference("#{model_class}.count", -1) do
      yield
    end
  end

  # Helper method to verify that a record was not deleted
  def assert_record_not_deleted(model_class)
    assert_no_difference("#{model_class}.count") do
      yield
    end
  end
end
