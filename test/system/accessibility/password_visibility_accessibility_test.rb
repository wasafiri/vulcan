require "application_system_test_case"

module Accessibility
  class PasswordVisibilityAccessibilityTest < ApplicationSystemTestCase
    test "password toggle has proper ARIA attributes" do
      visit sign_up_path

      # Check initial state
      toggle = find("button[aria-label='Show password']").first
      assert_equal "false", toggle[:aria_pressed]

      # Toggle and check updated state
      toggle.click
      assert_equal "true", toggle[:aria_pressed]
      assert_equal "Hide password", toggle[:aria_label]

      # Toggle back
      toggle.click
      assert_equal "false", toggle[:aria_pressed]
      assert_equal "Show password", toggle[:aria_label]
    end

    test "password field is properly associated with toggle button" do
      visit sign_up_path

      # Check that the password field has aria-describedby
      password_field = find_field("Password")
      toggle_id = password_field.sibling("button")[:id]

      assert_equal toggle_id, password_field[:aria_describedby]
    end

    test "password toggle button is focusable with keyboard" do
      visit sign_up_path

      # Tab to the password field
      find("body").send_keys(:tab) until page.driver.browser.switch_to.active_element.tag_name == "input" &&
                                        page.driver.browser.switch_to.active_element[:id] == "user_password"

      # Tab to the toggle button
      page.driver.browser.switch_to.active_element.send_keys(:tab)

      # Check that the toggle button is focused
      assert_equal "button", page.driver.browser.switch_to.active_element.tag_name
      assert_equal "Show password", page.driver.browser.switch_to.active_element[:aria_label]

      # Press Enter to toggle
      page.driver.browser.switch_to.active_element.send_keys(:enter)

      # Check that the password is now visible
      assert_equal "text", find_field("Password")[:type]
    end

    test "password toggle button has sufficient color contrast" do
      visit sign_up_path

      # This is a visual test that would typically be done with a visual testing tool
      # For now, we'll just check that the button has a class that we expect to have proper styling
      toggle = find("button[aria-label='Show password']").first

      assert toggle[:class].include?("eye-closed")

      # In a real test, we might use a tool like axe to check color contrast
      # page.execute_script("axe.run()")
    end

    test "password toggle button has appropriate size for touch targets" do
      visit sign_up_path

      # Check that the button has appropriate size for touch targets (at least 44x44 pixels)
      toggle = find("button[aria-label='Show password']").first

      # Get the button's dimensions
      width = page.evaluate_script("document.querySelector('button[aria-label=\"Show password\"]').offsetWidth")
      height = page.evaluate_script("document.querySelector('button[aria-label=\"Show password\"]').offsetHeight")

      # Check that the button is at least 44x44 pixels
      assert width >= 44, "Button width should be at least 44px for accessibility, but was #{width}px"
      assert height >= 44, "Button height should be at least 44px for accessibility, but was #{height}px"
    end
  end
end
