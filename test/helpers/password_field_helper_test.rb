require "test_helper"

class PasswordFieldHelperTest < ActionView::TestCase
  include PasswordFieldHelper

  test "generates password field with toggle button using Rails helpers" do
    form = ActionView::Helpers::FormBuilder.new("user", User.new, self, {})

    result = password_field_with_toggle(form, :password)

    # Check that it contains the password field
    assert_match /<input.*type="password".*id="user_password"/, result

    # Check that it contains the toggle button
    assert_match /<button.*data-action="visibility#togglePassword"/, result

    # Check that it contains the status element
    assert_match /<div.*id="user_password_visibility_status"/, result

    # Check that it contains the correct data attributes
    assert_match /data-visibility-target="field"/, result
  end

  test "accepts custom label" do
    form = ActionView::Helpers::FormBuilder.new("user", User.new, self, {})

    result = password_field_with_toggle(form, :password, label: "Custom Label")

    # Check that it contains the custom label
    assert_match /<label.*>Custom Label<\/label>/, result
  end

  test "accepts hint text" do
    form = ActionView::Helpers::FormBuilder.new("user", User.new, self, {})

    result = password_field_with_toggle(form, :password, hint: "Hint text")

    # Check that it contains the hint text
    assert_match /<p.*class="text-xs text-gray-500".*>Hint text<\/p>/, result
  end

  test "passes html options to the input" do
    form = ActionView::Helpers::FormBuilder.new("user", User.new, self, {})

    result = password_field_with_toggle(form, :password, html_options: {
      minlength: 8,
      placeholder: "Enter password"
    })

    # Check that it includes the custom attributes
    assert_match /minlength="8"/, result
    assert_match /placeholder="Enter password"/, result
  end

  test "uses correct autocomplete attribute for confirmation fields" do
    form = ActionView::Helpers::FormBuilder.new("user", User.new, self, {})

    result = password_field_with_toggle(form, :password_confirmation)

    # Check that it uses the correct autocomplete attribute
    assert_match /autocomplete="new-password"/, result

    # Check that it uses the correct data attribute
    assert_match /data-visibility-target="fieldConfirmation"/, result
  end

  test "includes accessibility attributes" do
    form = ActionView::Helpers::FormBuilder.new("user", User.new, self, {})

    result = password_field_with_toggle(form, :password)

    # Check that it includes the correct aria attributes
    assert_match /aria-describedby="user_password_visibility_status"/, result
    assert_match /aria-label="Show password"/, result
    assert_match /aria-pressed="false"/, result
    assert_match /aria-hidden="true"/, result
    assert_match /aria-live="polite"/, result
  end
end
