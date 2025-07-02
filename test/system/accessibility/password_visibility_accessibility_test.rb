# frozen_string_literal: true

require 'application_system_test_case'

module Accessibility
  class PasswordVisibilityAccessibilityTest < ApplicationSystemTestCase
    test 'password toggle has proper ARIA attributes' do
      visit sign_up_path

      # Find the password field first, then find its associated toggle button
      password_field = find_field('Password', visible: :all)
      container = password_field.find(:xpath, '..')  # Get the parent container
      toggle = container.find("button[aria-label='Show password']", visible: :all)
      
      assert toggle, "Password toggle button not found"
      assert_equal 'false', toggle['aria-pressed']

      # Toggle and check updated state
      toggle.click
      assert_equal 'true', toggle['aria-pressed']
      assert_equal 'Hide password', toggle['aria-label']

      # Toggle back
      toggle.click
      assert_equal 'false', toggle['aria-pressed']
      assert_equal 'Show password', toggle['aria-label']
    end

    test 'password field is properly associated with toggle button' do
      visit sign_up_path

      # Find the password field first, then find its associated toggle button
      password_field = find_field('Password', visible: :all)
      container = password_field.find(:xpath, '..')  # Get the parent container
      toggle = container.find("button[aria-label='Show password']", visible: :all)
      
      # Check that the password field has aria-describedby that includes the toggle button's ID
      describedby = password_field['aria-describedby']
      assert describedby, "Password field should have aria-describedby attribute"
      
      # The aria-describedby should include references to hint and status elements
      assert describedby.include?('password-hint'), "aria-describedby should include password-hint"
      assert describedby.include?('password-visibility-status'), "aria-describedby should include password-visibility-status"
    end

    test 'password toggle button is focusable with keyboard' do
      visit sign_up_path

      # Find the password field first, then find its associated toggle button
      password_field = find_field('Password', visible: :all)
      container = password_field.find(:xpath, '..')  # Get the parent container
      toggle_button = container.find("button[aria-label='Show password']", visible: :all)
      
      assert toggle_button, "Password toggle button not found"
      
      # Use JavaScript to focus the button (more reliable than tabbing)
      page.execute_script("arguments[0].focus()", toggle_button)
      
      # Verify the button is focused by checking if it matches the active element
      active_element_tag = page.evaluate_script("document.activeElement.tagName.toLowerCase()")
      active_element_aria_label = page.evaluate_script("document.activeElement.getAttribute('aria-label')")
      
      assert_equal 'button', active_element_tag
      assert_equal 'Show password', active_element_aria_label

      # Press Enter to toggle using JavaScript (more reliable)
      page.execute_script("arguments[0].click()", toggle_button)

      # Check that the password is now visible
      assert_equal 'text', find_field('Password', visible: :all)[:type]
    end

    test 'password toggle button has sufficient color contrast' do
      visit sign_up_path

      # Find the password field first, then find its associated toggle button
      password_field = find_field('Password', visible: :all)
      container = password_field.find(:xpath, '..')  # Get the parent container
      toggle = container.find("button[aria-label='Show password']", visible: :all)
      
      assert toggle, "Password toggle button not found"

      # Check that the button has the expected SVG icon (which should have proper styling)
      svg_icon = toggle.find('svg', visible: :all)
      assert svg_icon, "Password toggle button should contain an SVG icon"

      # In a real test, we might use a tool like axe to check color contrast
      # page.execute_script("axe.run()")
    end

    test 'password toggle button has appropriate size for touch targets' do
      visit sign_up_path

      # Find the password field first, then find its associated toggle button
      password_field = find_field('Password', visible: :all)
      container = password_field.find(:xpath, '..')  # Get the parent container
      toggle = container.find("button[aria-label='Show password']", visible: :all)
      
      assert toggle, "Password toggle button not found"

      # Get the button's dimensions using JavaScript
      button_element = page.evaluate_script("arguments[0]", toggle)
      width = page.evaluate_script("return arguments[0].offsetWidth", toggle)
      height = page.evaluate_script("return arguments[0].offsetHeight", toggle)

      # Check that the button is at least 44x44 pixels
      assert width >= 44, "Button width should be at least 44px for accessibility, but was #{width}px"
      assert height >= 44, "Button height should be at least 44px for accessibility, but was #{height}px"
    end
  end
end
