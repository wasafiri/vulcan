ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "mocha/minitest"
require "capybara/rails"
require "support/voucher_test_helper"
require "support/mailer_test_helper"

module ActiveSupport
  class TestCase
    include FactoryBot::Syntax::Methods
    include VoucherTestHelper
    include ActionMailer::TestHelper
    include MailerTestHelper

    def assert_enqueued_email_with(mailer_class, method_name, args: nil)
      block_result = nil
      assert_enqueued_with(job: ActionMailer::MailDeliveryJob) do
        block_result = yield
      end
      block_result
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
    def sign_in(user)
      if respond_to?(:post)
        # Integration test
        post sign_in_path, params: {
          email: user.email, password: "password123"
        }
      else
        # Controller/Model test
        session = user.sessions.create!(
          user_agent: "Rails Testing",
          ip_address: "127.0.0.1"
        )
        cookies[:session_token] = session.session_token
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

    def sign_out
      if respond_to?(:delete)
        # Integration test
        delete sign_out_path
      else
        # Controller/Model test
        cookies.delete(:session_token)
      end
    end

    def assert_requires_verification
      assert_response :redirect
      assert_redirected_to new_verification_path
      assert_equal "Please verify your account first", flash[:alert]
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
