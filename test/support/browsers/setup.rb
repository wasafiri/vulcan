# frozen_string_literal: true

require 'capybara'
require 'selenium-webdriver'
require_relative 'version'
require_relative 'paths'

module TestBrowsers
  # Main configuration method to set up Chrome
  def self.configure!
    # Use webdrivers gem for Chrome/ChromeDriver management
    fallback_to_webdrivers

    # Register the custom Chrome driver
    register_chrome_driver

    # Set default driver to our custom driver
    Capybara.javascript_driver = :chrome_headless

    puts 'Chrome configuration complete!' if ENV['VERBOSE_TESTS']
  end

  # Register a custom Capybara driver that uses standard Chrome
  def self.register_chrome_driver
    Capybara.register_driver :chrome_headless do |app|
      # Create Chrome options
      options = chrome_options

      puts "Registering Chrome driver with options: #{options.args.join(', ')}" if ENV['VERBOSE_TESTS']

      # Create and return the Selenium driver
      Capybara::Selenium::Driver.new(
        app,
        browser: :chrome,
        options: options,
        # Add timeout options to help with connection issues
        http_client: Selenium::WebDriver::Remote::Http::Default.new(
          read_timeout: 120,
          open_timeout: 120
        )
      )
    end
  end

  # Configure Chrome options for testing
  def self.chrome_options
    options = Selenium::WebDriver::Chrome::Options.new

    # Common options for testing
    options.add_argument('--headless=new')
    options.add_argument('--disable-gpu')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--window-size=1400,1000')
    # Only add verbose logging when explicitly requested
    if ENV['VERBOSE_TESTS']
      options.add_argument('--verbose')
      options.add_argument('--enable-logging')
      options.add_argument('--log-level=0')
    else
      # Quiet mode - suppress most logging
      options.add_argument('--log-level=3') # Only fatal errors
      options.add_argument('--silent')
    end

    # Performance optimizations
    options.add_argument('--disable-site-isolation-trials')
    options.add_argument('--disable-renderer-backgrounding')
    options.add_argument('--disable-backgrounding-occluded-windows')
    options.add_argument('--memory-pressure-off')
    options.add_argument('--disable-hang-monitor')

    # Browser security/feature flags
    options.add_argument('--disable-infobars')
    options.add_argument('--disable-popup-blocking')
    options.add_argument('--disable-extensions')
    options.add_argument('--disable-background-networking')
    options.add_argument('--disable-default-apps')
    options.add_argument('--disable-sync')
    options.add_argument('--disable-translate')
    options.add_argument('--disable-web-security')
    options.add_argument('--safebrowsing-disable-auto-update')

    # More stability options
    options.add_argument('--enable-features=NetworkServiceInProcess2')
    options.add_argument('--disable-browser-side-navigation')
    options.add_argument('--disable-blink-features=BlockCredentialedSubresources')

    # Disable automation flags that might cause detection
    options.add_argument('--disable-blink-features=AutomationControlled')

    # Debug logging when needed (only in verbose mode)
    if ENV['VERBOSE_TESTS']
      options.add_argument('--enable-logging')
      options.add_argument('--v=1')
    end

    # Add option to maintain connection
    options.add_argument('--disable-session-crashed-bubble')
    options.add_argument('--disable-application-cache')

    options
  end

  # Use webdrivers gem for Chrome/ChromeDriver management
  def self.fallback_to_webdrivers
    puts 'Using webdrivers gem for browser automation' if ENV['VERBOSE_TESTS']

    require 'webdrivers'

    # Reset any previously set version requirements
    Webdrivers::Chromedriver.required_version = nil

    begin
      # Try to update ChromeDriver
      Webdrivers::Chromedriver.update
      true
    rescue StandardError => e
      puts "Warning: ChromeDriver update failed: #{e.message}" if ENV['VERBOSE_TESTS']
      false
    end
  end
end
