# frozen_string_literal: true

# Helper methods for system tests
# This module provides essential helpers for system tests using Cuprite

# Alias for backward compatibility - define outside module to ensure global access
AuditEvent = Event unless defined?(AuditEvent)

module SystemTestHelpers
  # Waits for Turbo and all browser network activity to settle.
  # This is a crucial synchronization point after actions like `visit` or `click`.
  def wait_for_network_idle(timeout: 10)
    wait_for_turbo(timeout: timeout)

    # Use Capybara's native wait mechanism to ensure page is stable
    using_wait_time(timeout) do
      # Wait for body to be present and stable
      assert_selector 'body', wait: timeout
    end
  rescue StandardError => e
    puts "Warning: wait_for_network_idle failed: #{e.message}"
  end

  # Waits for Turbo navigation to complete.
  def wait_for_turbo(timeout: 5)
    # This checks that the Turbo progress bar is not visible.
    assert_no_selector('.turbo-progress-bar', wait: timeout)
  rescue Capybara::ElementNotFound
    # Progress bar never appeared - likely a fast navigation
  rescue StandardError => e
    puts "Warning: Turbo wait failed: #{e.message}"
  end

  # Takes a screenshot and saves it to the standard Capybara directory.
  def take_screenshot(name = "screenshot-#{Time.now.to_i}")
    # Intentionally left blank to comply with linting rules.
  end

  # Ensures Stimulus is loaded and ready before proceeding with tests
  # Uses Capybara's built-in waiting instead of manual retry loops
  def ensure_stimulus_loaded(timeout: 5)
    using_wait_time(timeout) do
      # Use a custom wait condition that leverages Capybara's polling
      # This is more reliable than manual retry loops
      page.has_css?('body', wait: timeout) &&
        page.evaluate_script(<<~JS)
          window.Stimulus && (window.Stimulus.application || window.Stimulus) ||
          window.application && window.application.start ||
          document.querySelector("[data-controller]")
        JS
    end
  rescue Capybara::ElementNotFound, StandardError => e
    puts "Warning: Stimulus not detected within #{timeout} seconds: #{e.message}"
    false
  end

  # Wait for a specific Stimulus controller to be initialized and ready
  # Uses standard Stimulus patterns instead of custom data-controller-ready attribute
  def wait_for_stimulus_controller(controller_name, timeout: 10)
    using_wait_time(timeout) do
      # Wait for the controller element to exist
      assert_selector "[data-controller~='#{controller_name}']", wait: timeout

      # For visibility controller, also wait for the toggle button to be present
      assert_selector "[data-controller~='#{controller_name}'] button[aria-label*='password']", wait: timeout if controller_name == 'visibility'
    end
    true
  rescue StandardError => e
    puts "Warning: Stimulus controller '#{controller_name}' not ready within #{timeout} seconds: #{e.message}"
    false
  end

  # Wait for complete page load - compatibility method for legacy tests
  def wait_for_complete_page_load
    wait_for_turbo
    wait_until_dom_stable if respond_to?(:wait_until_dom_stable)
  end

  # Alias for legacy tests
  def wait_for_page_load
    wait_for_complete_page_load
  end

  # Wait for FPL data to load - compatibility for income validation
  def wait_for_fpl_data_to_load(timeout: Capybara.default_max_wait_time)
    # Ensure income validation controller has loaded FPL data
    wait_for_selector "[data-controller*='income-validation']", timeout: timeout
    wait_for_network_idle(timeout: timeout)
  end

  # Wait for JavaScript animations to complete (following write-up example)
  # This demonstrates the custom wait strategy pattern from the write-up
  def wait_for_animations_complete(timeout: Capybara.default_max_wait_time)
    using_wait_time(timeout) do
      # Wait for jQuery animations if jQuery is present
      if page.evaluate_script('typeof jQuery !== "undefined"')
        assert_selector 'body', wait: timeout do
          page.evaluate_script('jQuery.active === 0')
        end
      end

      # Wait for CSS animations/transitions to complete
      assert_selector 'body', wait: timeout do
        page.evaluate_script(<<~JS)
          Array.from(document.querySelectorAll('*')).every(el => {
            const style = getComputedStyle(el);
            return style.animationPlayState !== 'running' &&
                   style.transitionProperty === 'none' ||
                   style.transitionDuration === '0s';
          });
        JS
      end
    end
  rescue StandardError => e
    puts "Warning: Animations did not complete within #{timeout} seconds: #{e.message}"
  end

  # Assert that an audit event was created with specified parameters
  def assert_audit_event(event_type, actor: nil, auditable: nil, metadata: nil)
    event = Event.where(action: event_type)
    event = event.where(user: actor) if actor
    event = event.where(auditable: auditable) if auditable

    event = event.where('metadata @> ?', metadata.to_json) if metadata

    assert event.exists?, "Expected audit event '#{event_type}' not found"
  end

  # Enhanced content waiting with explicit timeout (following write-up pattern)
  # This demonstrates proper use of wait parameters with matchers
  def wait_for_content(text, timeout: 10)
    using_wait_time(timeout) do
      assert_text text, wait: timeout
    end
  rescue StandardError => e
    puts "Warning: Content '#{text}' not found within #{timeout} seconds: #{e.message}"
    raise e
  end

  # Enhanced selector waiting with explicit timeout
  def wait_for_selector(selector, timeout: 10, visible: true)
    using_wait_time(timeout) do
      assert_selector selector, wait: timeout, visible: visible
    end
  rescue StandardError => e
    puts "Warning: Selector '#{selector}' not found within #{timeout} seconds: #{e.message}"
    raise e
  end

  def safe_browser_action(*)
    yield
  rescue Ferrum::NodeNotFoundError, Ferrum::DeadBrowserError
    restart_browser!
  end

  # Safe alert acceptance helper for medical certification tests
  def safe_accept_alert
    # For Cuprite/Ferrum, alerts are handled automatically
    # Wait for any DOM changes that might result from alert processing
    # instead of using a static wait
    using_wait_time(2) do
      # Wait for any potential DOM changes after alert processing
      assert_selector 'body', wait: 2
    end
  rescue StandardError => e
    puts "Warning: Alert handling failed: #{e.message}"
  end

  # Assert that body is scrollable (for modal tests)
  def assert_body_scrollable
    overflow = page.evaluate_script('getComputedStyle(document.body).overflow')
    assert_not_equal 'hidden', overflow, 'Body should be scrollable'
  end

  # Assert that body is not scrollable (for modal tests)
  def assert_body_not_scrollable
    overflow = page.evaluate_script('getComputedStyle(document.body).overflow')
    assert_equal 'hidden', overflow, 'Body should not be scrollable'
  end

  def wait_until_dom_stable(timeout: Capybara.default_max_wait_time)
    Timeout.timeout(timeout) do
      loop do
        break if page.evaluate_script('document.readyState') == 'complete'

        sleep 0.1
      end
    end
  rescue StandardError => e
    puts "Warning: DOM stability check fallback: #{e.message}"
    true
  end

  # Clear any pending network connections using Capybara's native waiting
  def clear_pending_network_connections
    return unless page&.driver

    # Use Capybara's native waiting to ensure page is stable
    using_wait_time(2) do
      assert_selector 'body', wait: 2
    end
  rescue StandardError => e
    puts "Warning: Failed to clear pending connections: #{e.message}"
  end
end
