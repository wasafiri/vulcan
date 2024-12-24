ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require 'factory_bot_rails'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Include FactoryBot methods
  include FactoryBot::Syntax::Methods

  # Add more helper methods to be used by all tests here...
  
  def sign_in_as(user)
    post(sign_in_url, params: { email: user.email, password: "SecurePass123!" })
    user
  end
end
