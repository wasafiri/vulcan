ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "factory_bot_rails"
require "database_cleaner/active_record"

# Require all files in test/support
Dir[Rails.root.join("test", "support", "**", "*.rb")].each { |f| require f }

# Configure DatabaseCleaner
DatabaseCleaner.strategy = :transaction

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods
  include TestPasswordHelper

  # Make helper methods available in fixtures
  ActiveRecord::FixtureSet.context_class.include(TestPasswordHelper)

  # Start DatabaseCleaner before each test
  setup do
    DatabaseCleaner.start
  end

  # Setup fixtures for all tests in alphabetical order.
  fixtures :all  # Ensure all fixtures are loaded only in test

  # Clean the database after each test
  teardown do
    DatabaseCleaner.clean
  end
end

class ActionDispatch::IntegrationTest
  include FactoryBot::Syntax::Methods

  def sign_in(user, password: "password123")
    # Set standard test headers
    @headers = {
      "HTTP_USER_AGENT" => "Rails Testing",
      "REMOTE_ADDR" => "127.0.0.1"
    }

    post sign_in_path,
      params: { email: user.email, password: password },
      headers: @headers

    assert_response :redirect
    follow_redirect!
  end

  def sign_out
    delete sign_out_path
    assert_response :redirect
    follow_redirect!
  end

  def assert_application_in_list(application)
    assert_select ".application-row" do |elements|
      assert elements.any? { |e| e.text =~ /#{application.user.last_name}/ }
    end
  end

  def assert_application_row(application)
    assert_select ".application-row", text: /#{application.user.last_name}/i
  end

  # Helper to run test in main thread with Current attributes
  def with_current_attributes(user)
    Current.set(request, user)
    yield
  ensure
    Current.reset
  end

  # Alias sign_in_as to sign_in for compatibility with existing tests
  alias_method :sign_in_as, :sign_in
end

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include TestPasswordHelper
  include ActionDispatch::TestProcess::FixtureFile

  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  def sign_in_as(user, password: "password123")
    visit sign_in_path
    fill_in "Email Address", with: user.email
    fill_in "Password", with: password
    click_button "Sign In"
  end
end
