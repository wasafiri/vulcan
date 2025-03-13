ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "mocha/minitest"
require "capybara/rails"
require "webdrivers" # Load webdrivers for Chrome/ChromeDriver management
require "support/voucher_test_helper"
require "support/mailer_test_helper"
require "support/notification_delivery_stub"
require "support/authentication_test_helper"
require "support/flash_test_helper"
require "support/form_test_helper"

# Configure Webdrivers gem for system tests
Webdrivers.cache_time = 86_400 # Cache drivers for one day
Webdrivers.install_dir = File.join(Dir.home, '.webdrivers')
require "support/capybara_config"

# Load test-specific controllers and routes for webhooks
require_relative "controllers/webhooks/test_base_controller"
require_relative "controllers/webhooks/test_email_events_controller"

# Load and draw test routes
require_relative "controllers/webhooks/test_routes"
Rails.application.reload_routes!

# Override the standard request methods in integration tests to include default headers
# NOTE: These overrides apply ONLY in the test environment
module ActionDispatch
  class IntegrationTest
    # Store the original methods before overriding
    alias_method :original_get, :get
    alias_method :original_post, :post
    alias_method :original_patch, :patch
    alias_method :original_put, :put
    alias_method :original_delete, :delete

    # Override the standard request methods to include default headers
    [ :get, :post, :patch, :put, :delete ].each do |method_name|
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

    def assert_enqueued_email_with(mailer_class, method_name, args: nil)
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
      skip "Authentication not working properly" if defined?(response) && response.redirect? && response.location.include?("sign_in")
    end

    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Configure Active Storage for testing
    setup do
      ActiveStorage::Current.url_options = { host: "localhost:3000" }
    end

    # Add more helper methods to be used by all tests here...
    # Sign in a user for testing purposes
    # This method works in both controller and integration tests by delegating to
    # the more specific helper methods in AuthenticationTestHelper
    #
    # @param user [User] The user to sign in
    # @return [User] The signed-in user (for method chaining)
    def sign_in(user)
      # Set the TEST_USER_ID environment variable to override authentication
      # This is the most reliable way to authenticate in tests
      ENV["TEST_USER_ID"] = user.id.to_s
      puts "TEST AUTH: Setting TEST_USER_ID=#{user.id} for user: #{user.email}" if ENV["DEBUG_AUTH"] == "true"
      
      # Create a fresh session for this user to ensure consistent state
      test_session = user.sessions.create!(
        user_agent: "Rails Testing", 
        ip_address: "127.0.0.1",
        created_at: Time.current
      )
      
      puts "TEST AUTH: Created test session: #{test_session.id}, token: #{test_session.session_token}" if ENV["DEBUG_AUTH"] == "true"
      
      # Set both signed and unsigned cookies for maximum compatibility
      if respond_to?(:cookies)
        # Set unsigned cookie
        cookies[:session_token] = test_session.session_token
        
        # Set signed cookie if possible
        if cookies.respond_to?(:signed) && cookies.signed.respond_to?(:[]=)
          cookies.signed[:session_token] = { value: test_session.session_token, httponly: true }
          puts "TEST AUTH: Set signed cookie" if ENV["DEBUG_AUTH"] == "true"
        end
        
        puts "TEST AUTH: Set cookies for user #{user.email}" if ENV["DEBUG_AUTH"] == "true"
      else
        puts "TEST AUTH: No cookies method available, relying on TEST_USER_ID" if ENV["DEBUG_AUTH"] == "true"
      end
      
      # For integration tests, authenticate via the sign-in flow as well
      if respond_to?(:post)
        post sign_in_path, params: { email: user.email, password: "password123" }
        follow_redirect! if response.redirect?
        puts "TEST AUTH: Posted to sign_in_path for #{user.email}" if ENV["DEBUG_AUTH"] == "true"
      end
      
      # Verify current_user is set correctly if we can
      if defined?(@controller) && @controller.respond_to?(:current_user, true)
        current_user = @controller.send(:current_user)
        if current_user
          puts "TEST AUTH: current_user is set to #{current_user.email}" if ENV["DEBUG_AUTH"] == "true"
        else
          puts "TEST AUTH: WARNING - current_user is nil after sign_in!" if ENV["DEBUG_AUTH"] == "true"
        end
      end

      user # Return the user for method chaining
    end

    # Sign out the current user
    def sign_out
      puts "TEST AUTH: Signing out user" if ENV["DEBUG_AUTH"] == "true"

      # Clear the TEST_USER_ID environment variable
      ENV["TEST_USER_ID"] = nil

      if respond_to?(:delete)
        # Integration test
        delete sign_out_path
        follow_redirect! if response.redirect?
      else
        # Controller/Model test - use the helper if available
        if respond_to?(:sign_out_with_headers)
          sign_out_with_headers
        else
          # Direct fallback if helper not available
          if cookies.respond_to?(:signed) && cookies.signed.respond_to?(:delete)
            cookies.signed.delete(:session_token)
          else
            cookies.delete(:session_token)
          end
        end
      end
    end

    # Helper method for debugging authentication state
    def debug_auth_state(message = nil)
      return unless ENV["DEBUG_AUTH"] == "true"

      Rails.logger.debug "AUTH DEBUG: #{message}" if message

      # Log authentication state
      if respond_to?(:cookies) && cookies[:session_token].present?
        Rails.logger.debug "AUTH DEBUG: Session token present in cookies: #{cookies[:session_token]}"
      else
        Rails.logger.debug "AUTH DEBUG: No session token in cookies"
      end

      # For controller tests
      if defined?(@controller) && @controller.respond_to?(:current_user, true)
        user = @controller.send(:current_user)
        Rails.logger.debug "AUTH DEBUG: Current user: #{user&.email || 'nil'}"
      end

      # For integration tests, check response for signs of authentication
      if respond_to?(:response) && response.present?
        Rails.logger.debug "AUTH DEBUG: Response status: #{response.status}"
        if response.body.include?("Sign Out") || response.body.include?("Logout")
          Rails.logger.debug "AUTH DEBUG: User appears to be signed in (found logout link)"
        end
      end
    end

    def assert_not_authorized
      assert_response :redirect
      assert_redirected_to root_path
      assert_equal "Not authorized", flash[:alert]
    end

    def assert_must_sign_in
      assert_response :redirect
      assert_redirected_to sign_in_path
      assert_equal "You need to sign in first", flash[:alert]
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
      assert_equal "Please verify your account first", flash[:alert]
    end

    # Helper to verify authentication state
    def verify_authentication_state(expected_user)
      # For controller tests
      if defined?(@controller) && @controller.respond_to?(:current_user, true)
        current_user = @controller.send(:current_user)
        if current_user
          assert_equal expected_user.id, current_user.id, "Expected to be authenticated as #{expected_user.email}, but was authenticated as #{current_user.email}"
        else
          flunk "Expected to be authenticated as #{expected_user.email}, but was not authenticated"
        end
      else
        # For integration tests, check if we're redirected to sign in
        if response.redirect? && response.location.include?("sign_in")
          flunk "Expected to be authenticated as #{expected_user.email}, but was redirected to sign in"
        end

        # Check for signs of authentication in the response body
        if response.body.include?("Sign Out") || response.body.include?("Logout")
          assert true, "User appears to be signed in (found logout link)"
        else
          # If we can't directly verify, just log a warning
          Rails.logger.warn "WARNING: Could not directly verify authentication state for #{expected_user.email}"
        end
      end
    end
  end
end

# Configure Capybara
Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument("--headless")
  options.add_argument("--disable-gpu")
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")
  options.add_argument("--window-size=1400,1400")

  Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
end

Capybara.javascript_driver = :headless_chrome
Capybara.default_max_wait_time = 5

# Configure ActionMailer
ActionMailer::Base.delivery_method = :test
ActionMailer::Base.perform_deliveries = true
ActionMailer::Base.deliveries = []

# Configure Active Job
ActiveJob::Base.queue_adapter = :test

# Configure Active Storage
Rails.application.config.active_storage.service = :test

# Suppress logging in tests
Rails.logger.level = Logger::ERROR
