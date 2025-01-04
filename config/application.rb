require_relative "boot"
require "rails/all"

# Require the gems listed in Gemfile
Bundler.require(*Rails.groups)

# define the MatVulcan module and Application class
module MatVulcan
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    config.action_mailer.delivery_method = :postmark
    config.action_mailer.postmark_settings = {
      api_token: Rails.application.credentials.postmark_api_token
    }

    # Factory_bot configuration
    config.generators do |g|
      g.factory_bot dir: "test/factories"
      g.factory_bot suffix: false
      g.test_framework :minitest
      g.fixture_replacement :factory_bot, dir: "test/factories"
    end
  end
end
