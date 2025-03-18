# frozen_string_literal: true

require 'capybara'
require 'selenium-webdriver'
require_relative 'version'
require_relative 'paths'
require_relative 'downloader'

module TestBrowsers
  # Main configuration method to set up Chrome for Testing
  def self.configure!
    # Download Chrome for Testing and ChromeDriver if not already present
    Downloader.ensure_binaries!
    
    # Register the custom Chrome for Testing driver
    register_chrome_for_testing_driver
    
    # Set default driver to our custom driver
    Capybara.javascript_driver = :chrome_for_testing
    
    puts "Chrome for Testing configuration complete! Using version: #{Version::CHROME_VERSION}"
    puts "Chrome binary: #{Paths.chrome_binary}"
    puts "ChromeDriver binary: #{Paths.chromedriver_binary}"
    
    # Verify the binaries are executable
    if File.executable?(Paths.chrome_binary)
      puts "Chrome binary is executable ✓"
    else
      puts "WARNING: Chrome binary is not executable!"
      File.chmod(0755, Paths.chrome_binary) rescue nil
    end
    
    if File.executable?(Paths.chromedriver_binary)
      puts "ChromeDriver binary is executable ✓"
    else 
      puts "WARNING: ChromeDriver binary is not executable!"
      File.chmod(0755, Paths.chromedriver_binary) rescue nil
    end
  end
  
  # Register a custom Capybara driver that uses Chrome for Testing
  def self.register_chrome_for_testing_driver
    Capybara.register_driver :chrome_for_testing do |app|
      # Create Chrome options
      options = chrome_options
      
      # Configure the Chrome service to use our ChromeDriver
      service = chrome_service
      
      puts "Registering Chrome for Testing driver with options: #{options.args.join(', ')}"
      puts "ChromeDriver service path: #{service.path}"
      
      # Create and return the Selenium driver
      Capybara::Selenium::Driver.new(
        app,
        browser: :chrome,
        options: options,
        service: service,
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
    
    # Set the Chrome binary path to our downloaded version
    options.binary = Paths.chrome_binary.to_s
    
    # Common options for testing
    options.add_argument('--headless=new')
    options.add_argument('--disable-gpu')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')
    options.add_argument('--window-size=1400,1000')
    options.add_argument('--verbose')
    
    # Add this to give more details on session issues
    options.add_argument('--enable-logging')
    options.add_argument('--log-level=0')
    
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
    
    # Debug logging when needed
    options.add_argument('--enable-logging')
    options.add_argument('--v=1')
    
    # Set Chrome for Testing user data directory
    options.add_argument("--user-data-dir=#{Paths.root.join('user_data')}")
    
    # Add option to maintain connection
    options.add_argument('--disable-session-crashed-bubble')
    options.add_argument('--disable-application-cache')
    
    options
  end
  
  # Configure the Chrome service to use our ChromeDriver
  def self.chrome_service
    service = Selenium::WebDriver::Chrome::Service.new(
      path: Paths.chromedriver_binary.to_s,
      port: random_free_port,
      args: ['--verbose', '--log-path=chromedriver.log']
    )
    
    # Ensure ChromeDriver is executable
    File.chmod(0755, service.path) if File.exist?(service.path)
    
    service
  end
  
  # Find a random free port for ChromeDriver
  def self.random_free_port
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    server.close
    port
  end
  
  # Fallback to using webdrivers if our Chrome for Testing setup fails
  def self.fallback_to_webdrivers
    puts "Falling back to webdrivers gem for browser automation"
    
    require 'webdrivers'
    
    # Reset any previously set version requirements
    Webdrivers::Chromedriver.required_version = nil
    
    begin
      # Try to update ChromeDriver
      Webdrivers::Chromedriver.update
      true
    rescue StandardError => e
      puts "Warning: ChromeDriver update failed: #{e.message}"
      false
    end
  end
end
