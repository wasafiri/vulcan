# frozen_string_literal: true

# Helper methods for system tests
# This module provides enhanced helpers for system tests using Cuprite
module SystemTestHelpers
  # Configure Cuprite for system tests
  def self.included(base)
    # Use setup instead of before_setup which isn't available in ActionDispatch::SystemTestCase
    base.setup do
      # Configure Cuprite with enhanced options unless already configured
      configure_cuprite
    end
  end

  # Configure Cuprite with optimal settings
  def configure_cuprite
    return if @cuprite_configured

    # Disable CSS transitions and animations for faster tests
    if Capybara.respond_to?(:disable_animation=)
      Capybara.disable_animation = true
    else
      # Apply custom JS to disable animations if Capybara method not available
      begin
        page.execute_script(<<~JS)
          (function() {
            var style = document.createElement('style');
            style.type = 'text/css';
            style.innerHTML = '* { transition: none !important; animation: none !important; }';
            document.head.appendChild(style);
          })();
        JS
      rescue StandardError
        nil
      end
    end

    @cuprite_configured = true
  end

  # Helper to capture and close flash messages
  # This is useful when Capybara.disable_animation is enabled
  # as it will capture the text of a flash message and then close it
  # to prevent it from covering other elements on the page
  def flash_message
    # Get the flash message text
    message = find('.flash').text.split("\n").last

    # Close the flash message to prevent it from covering other elements
    find('.flash .close').click

    # Return the message text
    message
  end

  # Helper to scroll to an element if needed
  # Since Cuprite doesn't automatically scroll like Selenium sometimes did
  def scroll_to_element(selector_or_element)
    element = selector_or_element.is_a?(String) ? find(selector_or_element) : selector_or_element

    # Prefer JS scrollIntoView – Ferrum native scroll occasionally throws SyntaxError in headless Chrome
    begin
      page.execute_script('arguments[0].scrollIntoView({block: "center", inline: "nearest"})', element)
    rescue StandardError => e
      puts "JS scrollIntoView failed: #{e.class} #{e.message}; falling back to native scroll" if ENV['VERBOSE_TESTS']
      if page.driver.respond_to?(:scroll_to)
        begin
          page.driver.scroll_to(element.native)
        rescue StandardError => e2
          puts "Native scroll also failed: #{e2.class} #{e2.message}" if ENV['VERBOSE_TESTS']
        end
      end
    end

    element
  end

  # Helper to wait for Turbo navigation to complete - stabilized version
  def wait_for_turbo
    # Stabilized version to prevent RAF interference with Cuprite visibility checks
    Capybara.using_wait_time(5) do
      assert_no_css('.turbo-progress-bar')
    end
    # Brief pause to let RAF-driven toggles finish before Capybara DOM probing
    sleep 0.1
  end

  # Helper to click an element with scrolling if needed
  def safe_click(selector)
    element = scroll_to_element(selector)
    element.click
    # Allow slight pause for any pending JS to execute
    sleep 0.1
    wait_for_turbo
  rescue StandardError => e
    # If standard click fails, try JavaScript click
    puts "Standard click failed: #{e.message}, using JS click"
    element = selector.is_a?(String) ? find(selector) : selector
    page.execute_script('arguments[0].click()', element)
    wait_for_turbo
  end

  # Helper for filling in form fields with automatic scrolling
  def safe_fill_in(selector, with:)
    # If selector looks like a raw ID (no prefix, no spaces/attrs), prepend '#'
    css_selector = if selector.is_a?(String) && !selector.start_with?('#', '.', '[', 'input') && selector !~ /\s|\[|>/
                     "##{selector}"
                   else
                     selector
                   end

    begin
      element = scroll_to_element(css_selector)
      element.fill_in(with: with)
    rescue Capybara::ElementNotFound
      # Fallback to label-based fill_in for robustness
      fill_in selector.to_s.humanize, with: with
    end
  end

  # Helper for selecting options from dropdowns with automatic scrolling
  def safe_select(option, from:)
    element = scroll_to_element(from)
    element.select(option)
  end

  # Helper to wait for animations to complete - optimized version
  # Now it doesn't add unnecessary delay
  def wait_for_animations
    # Only wait if the page has animation elements actively animating
    return unless page.has_css?('.animate-in, .animate-out, [data-animation]')

    # Minimal wait only needed when animations are happening
    sleep 0.05
  end

  # Wait until Stimulus controllers are initialised (window.Stimulus present)
  def ensure_stimulus_loaded(timeout: 3)
    Capybara.using_wait_time(timeout) do
      page.evaluate_script('typeof window.Stimulus !== "undefined"')
    end
  rescue Capybara::NotSupportedByDriverError, Capybara::ElementNotFound
    # If evaluation not supported just proceed
    true
  end

  # Save a screenshot to the tmp/screenshots directory
  # This version avoids using debugging methods directly
  def take_screenshot(name = nil)
    name ||= "screenshot-#{Time.current.strftime('%Y%m%d%H%M%S')}"
    path = Rails.root.join("tmp/screenshots/#{name}.png")
    FileUtils.mkdir_p(Rails.root.join('tmp/screenshots'))

    # Use driver's screenshot method directly if available
    if page.driver.respond_to?(:save_screenshot)
      page.driver.save_screenshot(path.to_s)
    elsif defined?(page.driver.browser) && page.driver.browser.respond_to?(:save_screenshot)
      page.driver.browser.save_screenshot(path.to_s)
    end

    puts "Screenshot saved to #{path}"
    path
  end

  # Helper to debug page state
  def debug_page
    puts "Current URL: #{current_url}"
    puts "Current Path: #{current_path}"
    puts "Page HTML summary: #{page.html.to_s.slice(0, 500)}..."
    take_screenshot("debug-#{Time.now.to_i}")
  end

  # Wrapper similar to CupriteTestBridge#safe_interaction but generic
  def safe_browser_action
    yield
  rescue StandardError => e
    puts "safe_browser_action recovered from #{e.class}: #{e.message}"
    Capybara.reset_sessions! if defined?(Capybara)
    raise e if ENV['RAISE_BROWSER_ERRORS'] == 'true'
  end

  # Backwards-compatibility alias used by some older system tests
  def sign_in_as(user, **options)
    sign_in(user, **options) # `sign_in` is defined in ApplicationSystemTestCase
  end
end
