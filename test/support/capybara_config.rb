# Configure Capybara for more stable system tests
require 'capybara/rails'
require 'selenium-webdriver'

# Safely clean up only Chrome for Testing processes
# First check if regular Chrome is running
if RUBY_PLATFORM =~ /darwin/
  regular_chrome = `pgrep -f "Google Chrome$" | wc -l`.strip.to_i
  had_regular_chrome = regular_chrome > 0
  
  # Clean up Chrome for Testing processes only
  system("pkill -TERM -f 'Google Chrome for Testing' > /dev/null 2>&1 || true") 
  system("pkill -TERM -f 'chromedriver.*testing' > /dev/null 2>&1 || true")
  sleep 2
  
  # Only force kill if still running
  chrome_testing_count = `pgrep -f "Google Chrome for Testing" | wc -l`.strip.to_i
  if chrome_testing_count > 0
    puts "Chrome for Testing still running after SIGTERM, using force kill..."
    system("pkill -9 -f 'Google Chrome for Testing' > /dev/null 2>&1 || true")
  end
  
  # Verify regular Chrome wasn't affected
  if had_regular_chrome
    after_chrome = `pgrep -f "Google Chrome$" | wc -l`.strip.to_i
    if after_chrome > 0
      puts "✓ Regular Chrome browser preserved during Capybara setup"
    else
      puts "! Warning: Regular Chrome browser may have been affected - please check"
    end
  end
elsif RUBY_PLATFORM =~ /linux/
  # Linux version - similar approach but with platform-specific commands
  system("pkill -TERM -f 'chrome.*for.*testing' > /dev/null 2>&1 || true")
  sleep 2
  system("pkill -9 -f 'chrome.*for.*testing' > /dev/null 2>&1 || true")
end

# Global Capybara configuration
Capybara.configure do |config|
  config.default_max_wait_time = 5
  config.default_normalize_ws = true
  config.enable_aria_label = true
  config.automatic_label_click = true
  config.match = :prefer_exact
  config.ignore_hidden_elements = true
  config.server = :puma, { Silent: true }
  config.test_id = "data-testid"
end

# More stable headless Chrome configuration
Capybara.register_driver :ultra_stable_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new
  
  # Basic headless configuration
  options.add_argument('--headless=new')
  options.add_argument('--disable-gpu')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1000')
  
  # Performance optimizations
  options.add_argument('--disable-site-isolation-trials')
  options.add_argument('--disable-renderer-backgrounding')
  options.add_argument('--disable-backgrounding-occluded-windows')
  options.add_argument('--memory-pressure-off')
  options.add_argument('--disable-hang-monitor')
  options.add_argument('--disable-infobars')
  options.add_argument('--disable-popup-blocking')
  options.add_argument('--disable-extensions')
  options.add_argument('--disable-background-networking')
  options.add_argument('--disable-default-apps')
  options.add_argument('--disable-sync')
  options.add_argument('--disable-translate')
  options.add_argument('--disable-web-security')
  options.add_argument('--safebrowsing-disable-auto-update')
  options.add_argument('--disable-features=NetworkService')
  
  # Debug logging
  options.add_argument('--enable-logging')
  options.add_argument('--v=1')
  
  # Configure timeouts
  client = Selenium::WebDriver::Remote::Http::Default.new
  client.read_timeout = 60
  client.open_timeout = 10
  
  # Create the driver
  driver = Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options: options,
    http_client: client
  )
  
  # Set browser timeouts
  driver.browser.manage.timeouts.implicit_wait = 0
  driver.browser.manage.timeouts.page_load = 30
  driver.browser.manage.timeouts.script_timeout = 30
  
  driver
end

# Set default JS driver to our ultra stable version
Capybara.javascript_driver = :ultra_stable_chrome
