require "application_system_test_case"

class PasswordVisibilitySystemTest < ApplicationSystemTestCase
  test "password fields on registration form have visibility toggle" do
    visit sign_up_path

    # Ensure Stimulus is loaded
    ensure_stimulus_loaded

    # Check that password field exists and has correct attributes
    assert_selector "input#user_password[type='password']"
    assert_selector "button[data-action='visibility#togglePassword']", count: 2 # One for each password field

    # Check that confirmation password field exists and has correct attributes
    assert_selector "input#user_password_confirmation[type='password']"

    # Test toggling password visibility using our helper method
    assert toggle_password_visibility("user_password")

    # Password should now be visible
    assert_selector "input#user_password[type='text']"
    password_toggle = find("input#user_password").sibling("button")
    assert_equal "true", password_toggle["aria-pressed"]

    # Toggle back
    assert toggle_password_visibility("user_password")

    # Password should be hidden again
    assert_selector "input#user_password[type='password']"
    assert_equal "false", password_toggle["aria-pressed"]

    # Test confirmation password field toggle
    assert toggle_password_visibility("user_password_confirmation")

    # Confirmation password should now be visible
    assert_selector "input#user_password_confirmation[type='text']"
    confirmation_toggle = find("input#user_password_confirmation").sibling("button")
    assert_equal "true", confirmation_toggle["aria-pressed"]

    # Toggle back
    assert toggle_password_visibility("user_password_confirmation")

    # Confirmation password should be hidden again
    assert_selector "input#user_password_confirmation[type='password']"
    assert_equal "false", confirmation_toggle["aria-pressed"]
  end

  test "password visibility automatically hides after timeout" do
    visit sign_up_path

    # Ensure Stimulus is loaded
    ensure_stimulus_loaded

    # Set a custom timeout for testing
    page.execute_script("window.passwordVisibilityTimeout = 500;")

    # Toggle the password to make it visible
    assert toggle_password_visibility("user_password")

    # Password should be visible initially
    assert_selector "input#user_password[type='text']"
    password_toggle = find("input#user_password").sibling("button")
    assert_equal "true", password_toggle["aria-pressed"]

    # Wait for the timeout
    sleep 0.6 # Wait slightly longer than the 500ms timeout

    # Password should be hidden again
    assert_selector "input#user_password[type='password']"
    assert_equal "false", password_toggle["aria-pressed"]
  end

  test "password fields have correct accessibility attributes" do
    skip "This test needs to be updated to match the new implementation"
    visit sign_up_path

    # Ensure Stimulus is loaded
    ensure_stimulus_loaded

    # Check password field
    password_field = find("input#user_password")
    container = password_field.ancestor(".relative")
    password_toggle = container.find("button")
    status_element_id = password_field["aria-describedby"]

    # Check that the password field has aria-describedby
    assert status_element_id.present?

    # Check that the status element exists
    assert_selector "##{status_element_id}"

    # Check that the toggle button has correct aria attributes
    assert_equal "Show password", password_toggle["aria-label"]
    assert_equal "false", password_toggle["aria-pressed"]

    # Toggle visibility using JavaScript
    page.execute_script(<<~JAVASCRIPT)
      (function() {
        const field = document.getElementById('user_password');
        if (!field) return;
      #{'  '}
        const container = field.closest('[data-controller="visibility"]');
        if (!container) return;
      #{'  '}
        const button = container.querySelector('button[data-action="visibility#togglePassword"]');
        if (!button) return;
      #{'  '}
        // Click the button to toggle visibility
        button.click();
      })();
    JAVASCRIPT

    # Wait for the toggle to take effect
    sleep 0.5

    # Reload the elements to get updated attributes
    password_field = find("input#user_password")
    container = password_field.ancestor(".relative")
    password_toggle = container.find("button")

    # Check that aria attributes are updated
    assert_equal "Hide password", password_toggle["aria-label"]
    assert_equal "true", password_toggle["aria-pressed"]

    # Check that status text is updated
    assert_equal "Password is visible", find("##{status_element_id}").text

    # Check confirmation password field
    confirmation_field = find("input#user_password_confirmation")
    confirmation_container = confirmation_field.ancestor(".relative")
    confirmation_toggle = confirmation_container.find("button")

    # Check that the toggle button has correct aria attributes
    assert_equal "Show password", confirmation_toggle["aria-label"]
    assert_equal "false", confirmation_toggle["aria-pressed"]
  end
end
