# frozen_string_literal: true

require 'test_helper'

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SystemTestAuthentication # Include authentication helper
  include SystemTestHelpers # Include helpers for working with Cuprite
  include Rails.application.routes.url_helpers # Include URL helpers

  # Configure default URL options for system tests
  Rails.application.routes.default_url_options[:host] = 'www.example.com'

  # Switch from headless_chrome to cuprite
  driven_by :cuprite, using: :chromium, screen_size: [1400, 1400] do |driver_options|
    driver_options.timeout = 10 # Increase timeout to 60 seconds
  end
end
