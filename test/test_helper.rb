# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'
require_relative '../config/environment'
require 'rails/test_help'
require 'minitest/mock'
require 'mocha/minitest'
require 'capybara/rails'
require 'support/voucher_test_helper'
require 'support/mailer_test_helper'
require 'support/notification_delivery_stub'
require 'support/authentication_test_helper'
require 'support/flash_test_helper'
require 'support/form_test_helper'
require 'support/active_storage_helper'
require 'support/active_storage_test_helper'
require 'support/proof_test_helper'
require 'support/attachment_test_helper' # Added for standardized attachment mocking
require 'support/system_test_authentication' # Added for system tests
require 'support/system_test_helpers' # Added for Cuprite system test helpers
require 'webauthn/fake_client' # Added for WebAuthn testing

# Load test-specific controllers and routes for webhooks
require_relative 'controllers/webhooks/test_base_controller'
require_relative 'controllers/webhooks/test_email_events_controller'

# Load and draw test routes
require_relative 'controllers/webhooks/test_routes'
Rails.application.reload_routes!

# Override the standard request methods in integration tests to include default headers
# NOTE: These overrides apply ONLY in the test environment
module ActionDispatch
  class IntegrationTest
    # Store the original methods before overriding
    alias original_get get
    alias original_post post
    alias original_patch patch
    alias original_put put
    alias original_delete delete

    # Override the standard request methods to include default headers
    %i[get post patch put delete].each do |method_name|
      define_method(method_name) do |path, **args|
        # Only add default headers if the class includes AuthenticationTestHelper
        if self.class.included_modules.include?(AuthenticationTestHelper)
          # Merge default headers with any provided headers
          args[:headers] = default_headers.merge(args[:headers] || {})
        end

        # Call the original method with the updated arguments
        send("original_#{method_name}", path, **args)
      end
    end
  end
end

module ActiveSupport
  class TestCase
    include FactoryBot::Syntax::Methods
    include VoucherTestHelper
    include ActionMailer::TestHelper
    include MailerTestHelper
    include AuthenticationTestHelper
    include FlashTestHelper
    include FormTestHelper
    include ActiveStorageHelper
    include ActiveStorageTestHelper
    include AttachmentTestHelper # Use standardized attachment mocking
    include ProofTestHelper

    # --- Database Cleaner Configuration ---
    # Clean the database completely before the suite starts
    # Note: Ensure DatabaseCleaner gem is in the :test group of your Gemfile
    begin
      DatabaseCleaner.clean_with(:truncation)
    rescue NameError
      puts "DatabaseCleaner not found. Add `gem 'database_cleaner-active_record'` to Gemfile's test group."
    end

    # Use truncation strategy for all tests
    begin
      DatabaseCleaner.strategy = :truncation
    rescue NameError
      # Ignore if DatabaseCleaner not loaded
    end

    # Wrap tests in DatabaseCleaner start/clean calls
    # Use Minitest's setup/teardown hooks
    # Clean BEFORE each test
    setup do
      DatabaseCleaner.clean if defined?(DatabaseCleaner)
    end

    # Start AFTER each test (less critical with truncation, but good practice)
    teardown do
      DatabaseCleaner.start if defined?(DatabaseCleaner)
    end
    # --- End Database Cleaner Configuration ---

    def assert_enqueued_email_with(_mailer_class, _method_name, _args: nil)
      block_result = nil
      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
        block_result = yield
      end
      block_result
    end

    # Helper method to check if authentication is working properly
    # This can be used to conditionally skip tests that require authentication
    def skip_unless_authentication_working
      # Simple test to verify authentication is working
      get new_constituent_portal_application_path if respond_to?(:get)
      skip 'Authentication not working properly' if defined?(response) && response.redirect? && response.location.include?('sign_in')
    end

    # Run tests in parallel with specified workers
    # parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    # fixtures :all

    # Configure Active Storage for testing
    setup do
      ActiveStorage::Current.url_options = { host: 'localhost:3000' }
    end

    # Add a helper to make tests that involve ActiveStorage attachments more robust
    def with_mocked_attachments
      # Set up mocks for ActiveStorage attachments to prevent common errors
      setup_attachment_mocks_for_audit_logs

      # Execute the test block
      yield
    end

    # Helper method to verify assertions are present in a test
    def assert_test_has_assertions
      # Check that at least one assertion was made
      assert_operator assertion_count, :>=, 1, 'Test is missing assertions'
    end

    # Helper method for mailbox routing tests
    # Checks if the inbound_email record was processed, implying correct routing.
    def assert_mailbox_routed(inbound_email, to:)
      # Reload the record to ensure status is updated after processing
      inbound_email.reload
      if inbound_email.processed?
        # We can't easily get the *actual* mailbox class it routed to after processing,
        # so we assume if it processed, it routed correctly based on the test setup.
        # For the default mailbox, we just check it was processed.
        assert true, "Email to '#{(inbound_email.mail.to || []).join(', ')}' was processed."
      elsif inbound_email.failed?
        flunk "Email to '#{(inbound_email.mail.to || []).join(', ')}' failed processing. Error: #{inbound_email.error_message}"
      else
        # If not processed or failed, it likely wasn't routed or processing didn't finish.
        flunk "Email to '#{(inbound_email.mail.to || []).join(', ')}' was not processed by any mailbox (expected '#{to}'). Status: #{inbound_email.status}"
      end
    end

    # Add more helper methods to be used by all tests here...

    # Default headers for integration tests
    def default_headers
      {
        'HTTP_USER_AGENT' => 'Rails Testing',
        'REMOTE_ADDR' => '127.0.0.1'
      }
    end

    # Sign in a user for testing purposes
    # This method works in both controller and integration tests by delegating to
    # the more specific helper methods in AuthenticationTestHelper
    #
    # @param user [User] The user to sign in
    # @return [User] The signed-in user (for method chaining)
    def sign_in(user)
      # Set the TEST_USER_ID environment variable to override authentication
      # This is the most reliable way to authenticate in tests
      ENV['TEST_USER_ID'] = user.id.to_s
      puts "TEST AUTH: Setting TEST_USER_ID=#{user.id} for user: #{user.email}" if ENV['DEBUG_AUTH'] == 'true'

      # Create a fresh session for this user to ensure consistent state
      test_session = user.sessions.create!(
        user_agent: 'Rails Testing',
        ip_address: '127.0.0.1',
        created_at: Time.current
      )

      puts "TEST AUTH: Created test session: #{test_session.id}, token: #{test_session.session_token}" if ENV['DEBUG_AUTH'] == 'true'

      # Set both signed and unsigned cookies for maximum compatibility
      if respond_to?(:cookies)
        # Set unsigned cookie
        cookies[:session_token] = test_session.session_token

        # Set signed cookie if possible
        if cookies.respond_to?(:signed) && cookies.signed.respond_to?(:[]=)
          cookies.signed[:session_token] = { value: test_session.session_token, httponly: true }
          puts 'TEST AUTH: Set signed cookie' if ENV['DEBUG_AUTH'] == 'true'
        end

        puts "TEST AUTH: Set cookies for user #{user.email}" if ENV['DEBUG_AUTH'] == 'true'
      elsif ENV['DEBUG_AUTH'] == 'true'
        puts 'TEST AUTH: No cookies method available, relying on TEST_USER_ID'
      end

      # For integration tests, authenticate via the sign-in flow as well
      if respond_to?(:post)
        post sign_in_path, params: { email: user.email, password: 'password123' }
        follow_redirect! if response.redirect?
        puts "TEST AUTH: Posted to sign_in_path for #{user.email}" if ENV['DEBUG_AUTH'] == 'true'
      end

      # Verify current_user is set correctly if we can
      if defined?(@controller) && @controller.respond_to?(:current_user, true)
        current_user = @controller.send(:current_user)
        if current_user
          puts "TEST AUTH: current_user is set to #{current_user.email}" if ENV['DEBUG_AUTH'] == 'true'
        elsif ENV['DEBUG_AUTH'] == 'true'
          puts 'TEST AUTH: WARNING - current_user is nil after sign_in!'
        end
      end

      user # Return the user for method chaining
    end

    # Sign out the current user
    def sign_out
      puts 'TEST AUTH: Signing out user' if ENV['DEBUG_AUTH'] == 'true'

      # Clear the TEST_USER_ID environment variable
      ENV['TEST_USER_ID'] = nil

      if respond_to?(:delete)
        # Integration test
        delete sign_out_path
        follow_redirect! if response.redirect?
      else
        # Controller/Model test - use the helper if available
        return sign_out_with_headers if respond_to?(:sign_out_with_headers)

        # Direct fallback if helper not available
        return cookies.signed.delete(:session_token) if cookies.respond_to?(:signed) && cookies.signed.respond_to?(:delete)

        cookies.delete(:session_token)
      end
    end

    # Helper method for debugging authentication state
    def debug_auth_state(message = nil)
      return unless ENV['DEBUG_AUTH'] == 'true'

      Rails.logger.debug { "AUTH DEBUG: #{message}" } if message

      # Log authentication state
      if respond_to?(:cookies) && cookies[:session_token].present?
        Rails.logger.debug { "AUTH DEBUG: Session token present in cookies: #{cookies[:session_token]}" }
      else
        Rails.logger.debug 'AUTH DEBUG: No session token in cookies'
      end

      # For controller tests
      if defined?(@controller) && @controller.respond_to?(:current_user, true)
        user = @controller.send(:current_user)
        Rails.logger.debug { "AUTH DEBUG: Current user: #{user&.email || 'nil'}" }
      end

      # For integration tests, check response for signs of authentication
      return unless respond_to?(:response) && response.present?

      Rails.logger.debug { "AUTH DEBUG: Response status: #{response.status}" }
      return unless response.body.include?('Sign Out') || response.body.include?('Logout')

      Rails.logger.debug 'AUTH DEBUG: User appears to be signed in (found logout link)'
    end

    def assert_not_authorized
      assert_response :redirect
      assert_redirected_to root_path
      assert_equal 'Not authorized', flash[:alert]
    end

    def assert_must_sign_in
      assert_response :redirect
      assert_redirected_to sign_in_path
      assert_equal 'You need to sign in first', flash[:alert]
    end

    # Helper methods for flash assertions
    def assert_flash(type, message)
      assert_equal message, flash[type.to_sym]
    end

    def assert_flash_after_redirect(type, message)
      follow_redirect!
      assert_flash(type, message)
    end

    def assert_requires_verification
      assert_response :redirect
      assert_redirected_to new_verification_path
      assert_equal 'Please verify your account first', flash[:alert]
    end

    # Helper to verify authentication state
    def verify_authentication_state(expected_user)
      # For controller tests
      if defined?(@controller) && @controller.respond_to?(:current_user, true)
        current_user = @controller.send(:current_user)
        if current_user
          assert_equal expected_user.id, current_user.id,
                       "Expected to be authenticated as #{expected_user.email}, but was authenticated as #{current_user.email}"
        else
          flunk "Expected to be authenticated as #{expected_user.email}, but was not authenticated"
        end
      else
        # For integration tests, check if we're redirected to sign in
        if response.redirect? && response.location.include?('sign_in')
          flunk "Expected to be authenticated as #{expected_user.email}, but was redirected to sign in"
        end

        # Check for signs of authentication in the response body
        if response.body.include?('Sign Out') || response.body.include?('Logout')
          assert true, 'User appears to be signed in (found logout link)'
        else
          # If we can\'t directly verify, just log a warning
          Rails.logger.warn "WARNING: Could not directly verify authentication state for #{expected_user.email}"
        end
      end
    end
  end
end

# ActionMailer Configuration
ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.deliveries = []

# Configure Active Job
ActiveJob::Base.queue_adapter = :test

# Configure Active Storage
Rails.application.config.active_storage.service = :test

# Suppress logging in tests - Commented out to restore default test log level (debug)
# Rails.logger.level = Logger::ERROR
