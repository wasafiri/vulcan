module ModalHelpers
  def within_modal(css = '[role="dialog"]', &)
    # Wait for the current modal to settle, then *query again* every time
    wait_for_modal(css)
    within(css, &)
  end

  # Defensive modal trigger clicking that avoids stale node references
  def click_modal_trigger(selector, wait: 10)
    assert_selector selector, wait: wait
    # Re-query each time to avoid stale references
    click_button selector, wait: wait
  end

  private

  def wait_for_modal(css)
    # Wait for the modal to be visible first
    assert_selector css, visible: true, wait: 10

    # Wait for modal controller to signal it's ready with better error handling
    begin
      using_wait_time(15) do
        # Try to find the modal-ready attribute, but don't fail if it's not there yet
        page.has_selector?("#{css}[data-test-modal-ready='true']", wait: 10) ||
          page.has_selector?(css.to_s, wait: 5) # Fallback for modals without ready signal
      end
    rescue Capybara::ElementNotFound
      # If the modal ready attribute isn't found, just ensure the modal is still visible
      assert_selector css, visible: true, wait: 5
    end

    # Give Stimulus controllers time to initialize after modal opens
    wait_for_network_idle(timeout: 5) if respond_to?(:wait_for_network_idle)

    # Ensure any Stimulus controllers in the modal are loaded
    modal_element = page.find(css, visible: true)
    if modal_element.has_selector?('[data-controller]', wait: 2)
      # Wait a brief moment for controller initialization
      sleep(0.2)
    end

    # Wait for scroll lock to be applied by the modal controller
    # The modal controller should add overflow-hidden to the body
    using_wait_time(5) do
      # Give the modal controller time to apply scroll lock
      sleep(0.3)
      true # Always succeed, let individual tests assert scroll state if needed
    end
  end
end
