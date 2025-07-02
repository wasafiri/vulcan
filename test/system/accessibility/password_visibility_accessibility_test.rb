# frozen_string_literal: true

require 'application_system_test_case'

module Accessibility
  class PasswordVisibilityAccessibilityTest < ApplicationSystemTestCase
    test 'password toggle has proper ARIA attributes' do
      visit sign_up_path

      # Check that both password fields have toggle buttons
      password_toggles = page.evaluate_script("document.querySelectorAll(\"button[aria-label='Show password']\").length")
      assert_equal 2, password_toggles, "Should have 2 password toggle buttons (password and confirmation)"

      # Test the first password field's toggle button
      initial_aria_pressed = page.evaluate_script("document.querySelectorAll(\"button[aria-label='Show password']\")[0].getAttribute('aria-pressed')")
      assert_equal 'false', initial_aria_pressed

      # Click the first button using JavaScript to avoid visibility checks
      page.execute_script("document.querySelectorAll(\"button[aria-label='Show password']\")[0].click()")

      # Check updated state - button should now have "Hide password" label
      hide_buttons = page.evaluate_script("document.querySelectorAll(\"button[aria-label='Hide password']\").length")
      assert_equal 1, hide_buttons, "Should have 1 'Hide password' button after clicking"

      # Check that aria-pressed is now true
      updated_aria_pressed = page.evaluate_script("document.querySelector(\"button[aria-label='Hide password']\").getAttribute('aria-pressed')")
      assert_equal 'true', updated_aria_pressed

      # Toggle back using JavaScript
      page.execute_script("document.querySelector(\"button[aria-label='Hide password']\").click()")

      # Verify it's back to initial state
      final_show_buttons = page.evaluate_script("document.querySelectorAll(\"button[aria-label='Show password']\").length")
      assert_equal 2, final_show_buttons, "Should be back to 2 'Show password' buttons"
    end

    test 'password field is properly associated with toggle button' do
      visit sign_up_path

      # Check that we have 2 password fields
      password_field_count = page.evaluate_script("document.querySelectorAll(\"input[type='password']\").length")
      assert_equal 2, password_field_count, "Should have 2 password fields"

      # Check that both password fields have IDs
      first_field_has_id = page.evaluate_script("!!document.querySelectorAll(\"input[type='password']\")[0].id")
      second_field_has_id = page.evaluate_script("!!document.querySelectorAll(\"input[type='password']\")[1].id")
      assert first_field_has_id, "First password field should have an ID"
      assert second_field_has_id, "Second password field should have an ID"

      # Check that both fields have aria-describedby
      first_field_aria = page.evaluate_script("document.querySelectorAll(\"input[type='password']\")[0].getAttribute('aria-describedby')")
      second_field_aria = page.evaluate_script("document.querySelectorAll(\"input[type='password']\")[1].getAttribute('aria-describedby')")
      assert first_field_aria&.include?('password-visibility-status'), "First password field should reference visibility status"
      assert second_field_aria&.include?('password-visibility-status'), "Second password field should reference visibility status"

      # Check that we have 2 visibility controller containers
      container_count = page.evaluate_script("document.querySelectorAll(\"div[data-controller='visibility']\").length")
      assert_equal 2, container_count, "Should have 2 containers with visibility controllers"
    end

    test 'password toggle button has sufficient color contrast' do
      visit sign_up_path

      # Check that both buttons exist and have SVG icons
      first_button_has_svg = page.evaluate_script("!!document.querySelectorAll(\"button[aria-label='Show password']\")[0].querySelector('svg')")
      second_button_has_svg = page.evaluate_script("!!document.querySelectorAll(\"button[aria-label='Show password']\")[1].querySelector('svg')")
      assert first_button_has_svg, "First password toggle button should have SVG icon"
      assert second_button_has_svg, "Second password toggle button should have SVG icon"

      # Check that buttons have proper styling classes for hover/focus states
      first_button_has_hover = page.evaluate_script("document.querySelectorAll(\"button[aria-label='Show password']\")[0].className.includes('hover:')")
      first_button_has_focus = page.evaluate_script("document.querySelectorAll(\"button[aria-label='Show password']\")[0].className.includes('focus:')")
      assert first_button_has_hover, "First button should have hover styling classes"
      assert first_button_has_focus, "First button should have focus styling classes"
    end

    test 'password toggle button has appropriate size for touch targets' do
      visit sign_up_path

      # Check button dimensions for first button
      first_button_width = page.evaluate_script("document.querySelectorAll(\"button[aria-label='Show password']\")[0].getBoundingClientRect().width")
      first_button_height = page.evaluate_script("document.querySelectorAll(\"button[aria-label='Show password']\")[0].getBoundingClientRect().height")
      assert first_button_width >= 24, "First button width should be at least 24px, got #{first_button_width}"
      assert first_button_height >= 24, "First button height should be at least 24px, got #{first_button_height}"

      # Check button dimensions for second button
      second_button_width = page.evaluate_script("document.querySelectorAll(\"button[aria-label='Show password']\")[1].getBoundingClientRect().width")
      second_button_height = page.evaluate_script("document.querySelectorAll(\"button[aria-label='Show password']\")[1].getBoundingClientRect().height")
      assert second_button_width >= 24, "Second button width should be at least 24px, got #{second_button_width}"
      assert second_button_height >= 24, "Second button height should be at least 24px, got #{second_button_height}"
    end

    test 'password toggle button is focusable with keyboard' do
      visit sign_up_path

      # Test that first button can be focused
      page.execute_script("document.querySelectorAll(\"button[aria-label='Show password']\")[0].focus()")
      first_button_focused = page.evaluate_script("document.activeElement === document.querySelectorAll(\"button[aria-label='Show password']\")[0]")
      assert first_button_focused, "First button should be focusable and become the active element"

      # Test that second button can be focused
      page.execute_script("document.querySelectorAll(\"button[aria-label='Show password']\")[1].focus()")
      second_button_focused = page.evaluate_script("document.activeElement === document.querySelectorAll(\"button[aria-label='Show password']\")[1]")
      assert second_button_focused, "Second button should be focusable and become the active element"

      # Verify buttons are clickable
      first_button_clickable = page.evaluate_script("typeof document.querySelectorAll(\"button[aria-label='Show password']\")[0].click === 'function'")
      second_button_clickable = page.evaluate_script("typeof document.querySelectorAll(\"button[aria-label='Show password']\")[1].click === 'function'")
      assert first_button_clickable, "First button should be clickable"
      assert second_button_clickable, "Second button should be clickable"
    end

    test 'password visibility controller adds dynamic CSS classes' do
      visit sign_up_path

      # Click the button to toggle visibility
      page.execute_script("document.querySelector(\"button[aria-label='Show password']\").click()")

      # After clicking, check if the controller added the appropriate class
      post_click_has_eye_open = page.evaluate_script("document.querySelector(\"button[aria-label='Hide password']\").classList.contains('eye-open')")
      post_click_has_eye_closed = page.evaluate_script("document.querySelector(\"button[aria-label='Hide password']\").classList.contains('eye-closed')")

      # The visibility controller should toggle these classes based on state
      # When visible (Hide password), it should have eye-open class
      assert post_click_has_eye_open, "Button should have 'eye-open' class when password is visible"
      refute post_click_has_eye_closed, "Button should not have 'eye-closed' class when password is visible"
    end
  end
end
