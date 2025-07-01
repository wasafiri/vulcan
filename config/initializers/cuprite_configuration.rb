# frozen_string_literal: true

# Configure Cuprite globally for system tests
if defined?(Capybara::Cuprite)
  Capybara.register_driver :cuprite do |app|
    Capybara::Cuprite::Driver.new(app, {
                                    js_errors: true,
                                    headless: %w[0 false].exclude?(ENV.fetch('HEADLESS', nil)),
                                    slowmo: ENV['SLOWMO']&.to_f,
                                    # Reduce timeouts for faster tests
                                    process_timeout: 5,
                                    timeout: 5,
                                    # Skip image loading for speed
                                    skip_image_loading: true,
                                    # Increase browser idle time
                                    browser_options: ENV['DOCKER'] ? { 'no-sandbox' => nil } : {}
                                  })
  end

  # Configure default driver
  Capybara.default_driver = :cuprite
  Capybara.javascript_driver = :cuprite

  # Set shorter waits for faster tests
  Capybara.default_max_wait_time = 2

  # Disable animations in Capybara for faster tests
  Capybara.disable_animation = true if Capybara.respond_to?(:disable_animation=)

  # Don't raise server errors
  Capybara.raise_server_errors = false

  # Share sessions between test cases for better performance
  Capybara.reuse_server = true
end
