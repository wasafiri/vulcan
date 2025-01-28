# test/test_helper.rb

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"
require "factory_bot_rails"
require "database_cleaner/active_record"

# Configure DatabaseCleaner
DatabaseCleaner.strategy = :transaction

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods

  # Start DatabaseCleaner before each test
  setup do
    DatabaseCleaner.start
  end

  # Clean the database after each test
  teardown do
    DatabaseCleaner.clean
  end
end

class ActionDispatch::IntegrationTest
  include FactoryBot::Syntax::Methods

  # Define a single sign_in method to avoid duplication
  def sign_in(user, password: "password123")
    post sign_in_path, params: { email: user.email, password: password }
    assert_response :redirect
    follow_redirect!
  end

  # Alias sign_in_as to sign_in for compatibility with existing tests
  alias_method :sign_in_as, :sign_in

  def sign_out
    delete sign_out_path
    assert_response :redirect
    follow_redirect!
  end
end
