ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "factory_bot_rails"

class ActiveSupport::TestCase
  include FactoryBot::Syntax::Methods

  def sign_in_as(user)
    post sign_in_path, params: { email: user.email, password: "password123" }
    assert_response :redirect
    follow_redirect!
  end

  def sign_out
    delete sign_out_path
    assert_response :redirect
    follow_redirect!
  end
end

# Clean the database between tests
class Minitest::Test
  def before_setup
    super
    DatabaseCleaner.start
  end

  def after_teardown
    DatabaseCleaner.clean
    super
  end
end
