# frozen_string_literal: true

if Rails.env.test?
  require 'capybara/rails'
  require 'capybara/cuprite'
  require 'socket' # Required for IPSocket

  # Configure Cuprite driver
  Capybara.register_driver(:cuprite) do |app|
    Capybara::Cuprite::Driver.new(
      app,
      window_size: [1440, 900],
      # See additional options for Docker: https://github.com/rubycdp/cuprite?tab=readme-ov-file#docker
      browser_options: ENV['DOCKER'] ? { 'no-sandbox' => nil } : {},
      # Increase Chrome startup wait time (required for CI)
      process_timeout: 15,
      # Enable debugging: https://github.com/rubycdp/cuprite?tab=readme-ov-file#debugging
      inspector: true,
      # Allow Cuprite to capture JS errors and convert to Ruby exceptions
      js_errors: true,
      # Enable headless mode by default but allow override via HEADLESS=0
      headless: !%w[0 false].include?(ENV.fetch('HEADLESS', 'true').downcase),
      # Slow down interactions for better visibility when not headless
      slowmo: ENV['SLOWMO']&.to_f
    )
  end

  # Use Cuprite driver for all tests
  Capybara.default_driver = :cuprite
  Capybara.javascript_driver = :cuprite

  # Disable CSS transitions and animations for faster, more reliable tests
  Capybara.disable_animation = true

  # Configuration for system tests
  Capybara.configure do |config|
    # Network settings for CI environments
    config.server_host = '0.0.0.0' # bind to all interfaces
    config.app_host = "http://#{IPSocket.getaddress(Socket.gethostname)}" if ENV['CI']

    # Configure server for system tests
    config.server = :puma, { Silent: true }

    # Reasonable default wait time (seconds) - longer in CI
    config.default_max_wait_time = ENV['CI'] ? 15 : 10

    # Input and interaction settings
    config.default_set_options = { clear: :backspace }
    config.automatic_label_click = true

    # Enable aria-label support
    config.enable_aria_label = true

    # Save path for Capybara screenshots
    config.save_path = Rails.root.join('tmp/capybara')
  end
end
