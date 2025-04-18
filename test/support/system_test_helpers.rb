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
      page.execute_script(<<~JS) rescue nil
        (function() {
          var style = document.createElement('style');
          style.type = 'text/css';
          style.innerHTML = '* { transition: none !important; animation: none !important; }';
          document.head.appendChild(style);
        })();
      JS
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
    find(".flash .close").click

    # Return the message text
    message
  end

  # Helper to scroll to an element if needed
  # Since Cuprite doesn't automatically scroll like Selenium sometimes did
  def scroll_to_element(selector_or_element)
    element = selector_or_element.is_a?(String) ? find(selector_or_element) : selector_or_element

    if page.driver.respond_to?(:scroll_to)
      # Use Cuprite's native scroll_to method if available
      page.driver.scroll_to(element.native, align: :center)
    else
      # Fallback to JavaScript
      page.execute_script('arguments[0].scrollIntoView({block: "center"})', element)
    end

    # Return the element for chaining
    element
  end

  # Helper to wait for Turbo navigation to complete - optimized version
  def wait_for_turbo
    # No need for sleep here, just check for the progress bar to be gone
    Capybara.using_wait_time(2) do
      has_no_css?('.turbo-progress-bar')
    end
  end

  # Helper to click an element with scrolling if needed
  def safe_click(selector)
    element = scroll_to_element(selector)
    element.click
    wait_for_turbo
  end

  # Helper for filling in form fields with automatic scrolling
  def safe_fill_in(selector, with:)
    element = scroll_to_element(selector)
    element.fill_in(with: with)
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
    if page.has_css?('.animate-in, .animate-out, [data-animation]')
      # Minimal wait only needed when animations are happening
      sleep 0.05
    end
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
end
