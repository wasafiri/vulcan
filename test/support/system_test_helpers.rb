module SystemTestHelpers
  # Safely perform browser actions with retry logic
  def safe_browser_action(retries = 3)
    attempt = 0
    begin
      yield
    rescue Selenium::WebDriver::Error::StaleElementReferenceError,
           Selenium::WebDriver::Error::ElementClickInterceptedError,
           Selenium::WebDriver::Error::InvalidSessionIdError => e
      attempt += 1
      if attempt <= retries
        puts "Browser action failed, retrying (#{attempt}/#{retries}): #{e.message}"
        sleep 1
        retry
      else
        raise e
      end
    end
  end

  # Safely accept alerts with stronger handling
  def safe_accept_alert
    alert_appeared = false
    begin
      # Set timeout for alert and increase the default wait time
      original_wait_time = Capybara.default_max_wait_time
      Capybara.default_max_wait_time = 10
      page.driver.browser.manage.timeouts.implicit_wait = 5
      
      # Execute the block that should trigger the alert
      yield
      
      # Wait a moment for the alert to appear
      sleep 1
      
      # Handle the alert more aggressively with retries
      5.times do |attempt|
        begin
          alert = page.driver.browser.switch_to.alert
          alert.accept
          alert_appeared = true
          break
        rescue Selenium::WebDriver::Error::NoSuchAlertError
          # Wait briefly and try again
          sleep 0.5
        rescue StandardError => e
          puts "Alert handling error on attempt #{attempt+1}: #{e.message}"
          # Try a longer wait on subsequent attempts
          sleep 1
        end
      end
      
      # If we couldn't handle the alert through normal means, try JavaScript
      unless alert_appeared
        begin
          page.execute_script("window.alert = function() {}; window.confirm = function() { return true; };")
        rescue StandardError => e
          puts "Failed to override alert functions with JS: #{e.message}"
        end
      end
    rescue StandardError => e
      puts "Error in safe_accept_alert: #{e.message}"
    ensure
      # Reset timeout and wait time
      page.driver.browser.manage.timeouts.implicit_wait = 0
      Capybara.default_max_wait_time = original_wait_time
    end
  end

  # Wait for both Turbo and animations to complete
  def wait_for_complete_page_load
    # First wait for Turbo loading bar to disappear
    has_no_css?(".turbo-progress-bar")
    
    # Then wait for any animations to finish
    sleep 0.5
    has_no_css?(".animate-spin")
    has_no_css?(".transition")
    
    # Wait for any AJAX requests to complete
    sleep 0.5
  end
end
