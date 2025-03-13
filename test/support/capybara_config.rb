# Configure Capybara for more stable system tests
require 'capybara/rails'
require 'selenium-webdriver'

# Safely clean up only Chrome for Testing processes
puts "Ensuring no stray Chrome for Testing processes before Capybara setup..."

# Helper to count processes matching pattern
def count_processes(pattern)
  `ps aux | grep -E "#{pattern}" | grep -v "grep" | wc -l`.strip.to_i
end

# More specific process counting for debugging
def debug_chrome_processes
  main_chrome = count_processes("Google Chrome$")
  testing_chrome = count_processes("Chrome for Testing")
  chromedriver = count_processes("chromedriver")
  
  puts "Regular Chrome processes: #{main_chrome}"
  puts "Chrome for Testing processes: #{testing_chrome}"
  puts "ChromeDriver processes: #{chromedriver}"
  
  [main_chrome, testing_chrome, chromedriver]
end

# Better process killing with pattern check
def kill_process_gracefully(pattern, name = "Process")
  count = count_processes(pattern)
  if count > 0
    puts "Found #{count} #{name} process(es), cleaning up..."
    system("pkill -TERM -f '#{pattern}' > /dev/null 2>&1 || true") 
    sleep 2
    
    # Check if still running after SIGTERM
    remaining = count_processes(pattern)
    if remaining > 0
      puts "#{name} still running after SIGTERM, using force kill..."
      system("pkill -9 -f '#{pattern}' > /dev/null 2>&1 || true")
    end
  end
end

# Debug before
puts "-- Chrome processes before cleanup --"
regular_chrome, testing_chrome, chromedriver = debug_chrome_processes

if RUBY_PLATFORM =~ /darwin/
  # macOS - precise pattern matching
  kill_process_gracefully("Chrome for Testing", "Chrome for Testing")
  kill_process_gracefully("chromedriver", "ChromeDriver")
  
  # Verify regular Chrome wasn't affected
  after_chrome = count_processes("Google Chrome$")
  
  puts "-- Chrome processes after cleanup --"
  debug_chrome_processes
  
  if regular_chrome > 0 && after_chrome > 0
    puts "✓ Regular Chrome browser preserved during Capybara setup"
  elsif regular_chrome > 0
    puts "! Warning: Regular Chrome browser may have been affected - please check"
  end
elsif RUBY_PLATFORM =~ /linux/
  # Linux - similar approach with platform-specific commands
  kill_process_gracefully("chrome.*for.*testing", "Chrome for Testing")
  kill_process_gracefully("chromedriver", "ChromeDriver")
  
  puts "-- Chrome processes after cleanup --"
  debug_chrome_processes
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
