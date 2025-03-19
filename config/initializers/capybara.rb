if Rails.env.test?
  require 'capybara/rails'
  require 'selenium/webdriver'
  require 'fileutils'
  require 'socket'

  # Generate a random port for debugging to avoid conflicts
  def find_available_port
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    server.close
    port
  rescue Errno::EADDRINUSE
    retry # Try again with a different port
  end

  # Improved Chrome for Testing binary finder
  def find_chrome_for_testing_path
    # Platform detection
    platform = case RUBY_PLATFORM
                when /darwin/
                  if RUBY_PLATFORM.include?('arm')
                    'mac-arm64'
                  else
                    'mac-x64'
                  end
                when /linux/
                  'linux'
                when /mingw|mswin/
                  'win64'
                else
                  nil
               end
    
    return nil unless platform
    
    # Search paths based on platform
    search_paths = []
    
    # Puppeteer paths - most reliable
    search_paths << File.join(Dir.home, '.cache', 'puppeteer', 'chrome', platform, '*')
    
    # Local project paths - set by bin/setup-test-browser
    search_paths << File.join(Rails.root, 'chrome', "*-*", "chrome-#{platform}")
    
    # Mac-specific app paths
    if platform.start_with?('mac')
      app_paths = [
        File.join(Rails.root, 'chrome', "*-*", "chrome-#{platform}", 'Google Chrome for Testing.app', 'Contents', 'MacOS', 'Google Chrome for Testing'),
        File.join(Dir.home, '.cache', 'puppeteer', 'chrome', platform, '*', 'Google Chrome for Testing.app', 'Contents', 'MacOS', 'Google Chrome for Testing'),
        '/Applications/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing'
      ]
      search_paths.concat(app_paths)
    end
    
    # Try each path and find the first matching file
    search_paths.each do |path|
      matches = Dir.glob(path)
      matches.each do |match|
        if File.directory?(match)
          # For directories, look for chrome/chrome.exe inside
          binary = case platform
                    when /mac/
                      File.join(match, 'chrome')
                    when /linux/
                      File.join(match, 'chrome')
                    when /win/
                      File.join(match, 'chrome.exe')
                   end
          
          return binary if binary && File.exist?(binary) && File.executable?(binary)
        elsif File.file?(match) && File.executable?(match)
          # Direct file match
          return match
        end
      end
    end
    
    # Fall back to looking for Chrome for Testing binary directly
    chromedriver_output = `npx @puppeteer/browsers list chrome | grep chrome@stable | head -n 1`
    if chromedriver_output.match(/browserPath: (.+)$/)
      chrome_path = $1.strip
      return chrome_path if File.exist?(chrome_path) && File.executable?(chrome_path)
    end

    # Fallback to standard Chrome as a last resort
    Rails.logger.warn "No Chrome for Testing binary found, using system Chrome"
    nil
  end

  # Register an improved headless Chrome driver
  Capybara.register_driver :headless_chrome do |app|
    # Find an available port
    debugging_port = find_available_port
    
    # Prepare Chrome options
    options = Selenium::WebDriver::Chrome::Options.new

    # Core settings for stability
    options.add_argument('--headless=new')  # New headless mode
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')

    # Performance and visibility settings
    options.add_argument('--window-size=1400,1400')
    options.add_argument('--disable-animations')
    options.add_argument('--disable-extensions')
    options.add_argument('--disable-gpu')
    
    # Let Chrome handle its own process and profile management
    options.add_argument("--remote-debugging-port=#{debugging_port}")
    
    # Set browser timeout to help identify hangs
    options.add_argument('--browser-timeout=60000')
    
    # Extra stability options
    options.add_argument('--disable-background-networking')
    options.add_argument('--enable-features=NetworkService,NetworkServiceInProcess')
    options.add_argument('--disable-background-timer-throttling')
    options.add_argument('--disable-backgrounding-occluded-windows')
    options.add_argument('--disable-breakpad')
    options.add_argument('--disable-component-extensions-with-background-pages')
    options.add_argument('--disable-features=TranslateUI,BlinkGenPropertyTrees')
    options.add_argument('--disable-ipc-flooding-protection')
    options.add_argument('--disable-renderer-backgrounding')
    options.add_argument('--force-color-profile=srgb')
    options.add_argument('--metrics-recording-only')
    options.add_argument('--mute-audio')

    # Use Chrome for Testing binary if available
    chrome_binary = find_chrome_for_testing_path
    if chrome_binary
      options.binary = chrome_binary
      Rails.logger.info "Using Chrome for Testing binary: #{chrome_binary}"
    else
      Rails.logger.warn "Using system Chrome (not recommended)"
    end

    # Set service options for better error handling
    service_options = {
      log_level: :error,
      args: ['--verbose', '--log-path=tmp/chromedriver.log']
    }

    # Create and configure driver with additional error handling
    begin
      driver = Capybara::Selenium::Driver.new(
        app,
        browser: :chrome,
        options: options,
        service: Selenium::WebDriver::Chrome::Service.new(options: service_options),
        timeout: 30
      )
      
      # Ensure browser is closed after tests
      at_exit do
        begin
          driver.quit if driver&.browser.respond_to?(:quit)
        rescue StandardError => e
          Rails.logger.error "Error closing browser: #{e.message}"
        end
      end
      
      driver
    rescue StandardError => e
      Rails.logger.error "Failed to create Chrome driver: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise
    end
  end

  # Use headless Chrome by default for all environments
  Capybara.default_driver = :headless_chrome
  Capybara.javascript_driver = :headless_chrome

  # Configuration for system tests
  Capybara.configure do |config|
    # Network settings for CI environments
    config.server_host = '0.0.0.0' # bind to all interfaces
    config.app_host = 'http://localhost' if ENV['CI']

    # Configure server for system tests
    config.server = :puma, { Silent: true }

    # Reasonable default wait time (seconds) - longer in CI
    config.default_max_wait_time = ENV['CI'] ? 15 : 10

    # Input and interaction settings
    config.default_set_options = { clear: :backspace }
    config.automatic_label_click = true
    
    # Exponential backoff for retries
    config.enable_aria_label = true
    config.save_path = Rails.root.join('tmp/capybara')
    
    # Set a shorter default wait time for this test file
    if ENV['TEST_FILE']&.include?('proof_uploads_test')
      puts "Detected proof_uploads_test, setting shorter timeout (5s)"
      config.default_max_wait_time = 5
    end
  end
  
  # Additional error recovery for system tests
  module Capybara
    module RescuableSession
      def reset_session!
        super
      rescue StandardError => e
        warn "CAPYBARA WARNING: Failed to reset session: #{e.message}"
        # Force browser to quit and restart
        if driver.respond_to?(:browser) && driver.browser.respond_to?(:quit)
          begin
            driver.browser.quit
          rescue StandardError => quit_error
            warn "CAPYBARA WARNING: Failed to quit browser: #{quit_error.message}"
          end
        end
        super # try again
      end
    end
    
    class Session
      prepend RescuableSession
    end
  end
end
