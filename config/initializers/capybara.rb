if Rails.env.test?
  require 'capybara/rails'
  require 'selenium/webdriver'
  require 'fileutils'

  # Create a dedicated chrome testing profile directory
  chrome_testing_profile = Rails.root.join('tmp/chrome_testing_profile')
  FileUtils.mkdir_p(chrome_testing_profile) unless Dir.exist?(chrome_testing_profile)

  # Find Chrome for Testing binary locations
  def find_chrome_for_testing_path
    # Check in local project first (this is where bin/setup-test-browser installs it)
    local_app_path = File.join(Rails.root, 'chrome', 'mac_arm-*', 'chrome-mac-arm64', 'Google Chrome for Testing.app', 'Contents', 'MacOS', 'Google Chrome for Testing')
    local_matches = Dir.glob(local_app_path)

    if local_matches.any? && File.exist?(local_matches.first)
      Rails.logger.info "Found Chrome for Testing at: #{local_matches.first}"
      return local_matches.first
    end

    # Check for direct binary (older installation method)
    local_chrome = File.join(Rails.root, 'chrome', 'mac_arm-*', 'chrome')
    local_matches = Dir.glob(local_chrome)

    if local_matches.any? && File.exist?(local_matches.first)
      Rails.logger.info "Found Chrome binary at: #{local_matches.first}"
      return local_matches.first
    end

    # Check in standard puppeteer location as a fallback
    puppeteer_path = File.join(Dir.home, '.cache', 'puppeteer', 'chrome', 'mac-arm64')

    if Dir.exist?(puppeteer_path)
      chrome_dirs = Dir.glob(File.join(puppeteer_path, '*')).select { |d| File.directory?(d) }
      latest_dir = chrome_dirs.sort_by { |d| File.mtime(d) }.last

      if latest_dir && File.exist?(File.join(latest_dir, 'chrome'))
        Rails.logger.info "Found Puppeteer Chrome at: #{File.join(latest_dir, 'chrome')}"
        return File.join(latest_dir, 'chrome')
      end
    end

    # Fallback to standard headless mode, which is not ideal
    # but will at least keep the tests running
    Rails.logger.warn "No Chrome for Testing binary found, using system Chrome"
    nil
  end

  # Register a standard headless Chrome driver that works in both local and CI environments
  Capybara.register_driver :headless_chrome do |app|
    options = Selenium::WebDriver::Chrome::Options.new

    # Core settings for stability
    options.add_argument('--headless')
    options.add_argument('--no-sandbox')
    options.add_argument('--disable-dev-shm-usage')

    # Performance and visibility settings
    options.add_argument('--window-size=1400,1400')
    options.add_argument('--disable-animations')
    options.add_argument('--disable-extensions')
    options.add_argument('--disable-gpu')

    # CRITICAL: Use a dedicated user data directory to prevent interference with regular Chrome
    options.add_argument("--user-data-dir=#{Rails.root.join('tmp/chrome_testing_profile')}")
    options.add_argument("--remote-debugging-port=9222") # Use a specific debugging port

    # Use Chrome for Testing binary if available
    chrome_binary = find_chrome_for_testing_path
    options.binary = chrome_binary if chrome_binary # Use specific Chrome binary if found

    # Create and configure driver
    driver = Capybara::Selenium::Driver.new(
      app,
      browser: :chrome,
      options: options
    )

    # Ensure browser is closed after tests
    at_exit do
      driver.quit if driver.respond_to?(:quit)
    end

    driver
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
    config.default_max_wait_time = ENV['CI'] ? 10 : 5

    # Input and interaction settings
    config.default_set_options = { clear: :backspace }
    config.automatic_label_click = true
  end
end
