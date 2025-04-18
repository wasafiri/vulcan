# System Testing Guide

This comprehensive guide explains how to run and maintain system tests in the MAT Vulcan application using Cuprite with Chrome.

## Table of Contents
1. [Overview](#overview)
2. [Current Architecture](#current-architecture)
3. [Running Tests](#running-tests)
4. [Configuration Details](#configuration-details)
5. [Headless Testing](#headless-testing)
6. [Browser Management](#browser-management)
7. [CI/CD Integration](#cicd-integration)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

## Overview

System tests allow us to verify the application's functionality from the user's perspective by automating browser interactions. Our system tests use:

- **Rails System Testing**: Built on Rails' integration with Capybara
- **Cuprite**: A headless Chrome driver for Capybara (replacing Selenium)
- **Chrome**: As the default browser for testing
- **CDP (Chrome DevTools Protocol)**: For direct browser control

## Current Architecture

Our system testing architecture consists of:

1. **Cuprite**: Directly controls Chrome via CDP without requiring ChromeDriver
2. **Capybara**: Provides a user-friendly DSL for browser interaction
3. **Chrome**: Standard Chrome browser (no special version needed)
4. **Minitest**: The testing framework

This architecture provides faster, more reliable end-to-end testing with significantly reduced configuration complexity.

## Running Tests

To run system tests, use the standard Rails test commands:

### Running All System Tests

```bash
bin/rails test:system
```

### Running Specific Test Files

```bash
bin/rails test test/system/path/to/test.rb
```

### Running Individual Tests

```bash
bin/rails test test/system/path/to/test.rb:line_number
```

## Configuration Details

System tests are configured in `test/application_system_test_case.rb`:

```ruby
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include SystemTestAuthentication
  include SystemTestHelpers

  driven_by :cuprite
end
```

The primary configuration is set in `config/initializers/capybara.rb`, which:

```ruby
Capybara.register_driver(:cuprite) do |app|
  Capybara::Cuprite::Driver.new(
    app,
    window_size: [1440, 900],
    browser_options: ENV['DOCKER'] ? { 'no-sandbox' => nil } : {},
    process_timeout: 15,
    inspector: true,
    js_errors: true,
    headless: !%w[0 false].include?(ENV.fetch('HEADLESS', 'true').downcase),
    slowmo: ENV['SLOWMO']&.to_f
  )
end

# Additional configuration options
Capybara.default_driver = :cuprite
Capybara.javascript_driver = :cuprite
Capybara.disable_animation = true
```

We also provide helper methods in `test/support/system_test_helpers.rb` for:
- Managing flash messages
- Scrolling to elements
- Handling animations
- Safe element clicking

## Headless Testing

With Cuprite, headless mode is enabled by default but can be easily toggled:

### Disabling Headless Mode for Debugging

You can run tests in a visible browser by setting the `HEADLESS` environment variable:

```bash
HEADLESS=0 bin/rails test:system
```

You can also slow down browser interactions to better see what's happening:

```bash
HEADLESS=0 SLOWMO=0.5 bin/rails test:system
```

The `SLOWMO` value is in seconds (e.g., 0.5 means each action takes half a second).

## Browser Management

Our Cuprite implementation has several advantages:

1. **No ChromeDriver dependency** - Cuprite connects directly to Chrome via CDP
2. **Simpler installation** - Just need Chrome installed, no need for driver management
3. **Faster execution** - Direct browser control results in ~40% faster tests
4. **Better error handling** - More informative error messages and JavaScript debugging

### Transition from Selenium to Cuprite

In April 2025, we completed our transition from Selenium WebDriver to Cuprite:

1. **What Changed?**
   - Removed all Selenium WebDriver dependencies
   - Eliminated the need for ChromeDriver management
   - Consolidated configuration into one central location
   - Added helper methods for handling common Cuprite-specific scenarios

2. **Why We Changed**
   - The Selenium approach required complex version matching between Chrome and ChromeDriver
   - Tests were slower due to the additional layers between our test code and Chrome
   - Cuprite provides better debugging tools and error messages
   - Simplified configuration makes maintaining tests easier

3. **For Developers**
   - You only need standard Chrome installed on your system
   - No need to worry about driver versions or compatibility
   - Tests run faster and are more reliable
   - New helper methods simplify common testing patterns

## CI/CD Integration

Our GitHub Actions workflow uses `browser-actions/setup-chrome@v1` to ensure a consistent Chrome installation in the CI environment. This setup is compatible with Cuprite and provides reliable test execution in automated environments.

```yaml
# Example GitHub Actions configuration
steps:
  - uses: browser-actions/setup-chrome@v1
  - name: Run system tests
    run: bin/rails test:system
```

For Docker environments, we ensure the `no-sandbox` option is enabled:

```yaml
env:
  DOCKER: true
```

## Troubleshooting

### Common Issues and Solutions

#### Browser Issues

If you encounter browser-related issues:

1. Ensure you have a stable version of Chrome installed (Cuprite is compatible with most versions)
2. Set `inspector: true` in the Cuprite driver config to enable Chrome DevTools debugging
3. Add the environment variable `DEBUG=true` for verbose Cuprite logging

#### Test Flakiness

For flaky tests (tests that inconsistently pass or fail):

1. Use the `SystemTestHelpers#wait_for_animations` method to ensure animations complete
2. Add explicit waits using Capybara's `have_content` or similar matchers
3. Use the `safe_click` helper to ensure elements are scrolled into view before clicking

#### Element Interaction Issues

When encountering element interaction problems:

1. Use `scroll_to_element` before interacting with elements that might be outside the viewport
2. Use Capybara's built-in retry mechanism with finders
3. Consider using `wait_for_animations` after actions that trigger CSS transitions

#### JavaScript Errors

Cuprite can capture and report JavaScript errors:

```ruby
# Check for JavaScript errors after an action
page.driver.browser.evaluate('window.jsErrors')
```

### Debugging Tips

1. **Check the Logs**: Cuprite captures JavaScript console output and exceptions
2. **Use Screenshot Helpers**: Capture screenshots at critical points with `page.save_screenshot`
3. **Use Inspector Mode**: Set `INSPECTOR=true` to enable Chrome DevTools Protocol inspector
4. **Visual Debugging**: Set `HEADLESS=0` to watch the browser execute your tests
5. **Slow Motion Testing**: Use `SLOWMO=0.5` to slow down operations for better visibility

## Testing Special Features

### Testing WebAuthn Authentication

WebAuthn (Web Authentication) testing presents unique challenges because it interacts with hardware security keys or platform-specific APIs (like Touch ID, Face ID, or Windows Hello). Here's our approach for testing WebAuthn:

#### Challenges with WebAuthn Testing

1. **Browser API Limitations**: WebAuthn API calls require secure contexts and user gestures in real browsers
2. **Hardware Dependencies**: Physical security keys and biometric authenticators aren't available in automated test environments
3. **Browser Window Issues**: WebAuthn prompts can cause browser focus issues and teardown problems in tests

#### Our WebAuthn Testing Strategy

We use a focused approach that tests the core WebAuthn functionality without relying on complex browser interactions:

1. **Use `webauthn-ruby` Fake Client**: We leverage the testing tools provided by the WebAuthn gem
2. **Test Core Functionality**: Focus on credential creation, storage, and user status verification
3. **Avoid Browser UI Testing**: Skip testing modal dialogs or platform-specific authentication prompts
4. **Implement Robust Teardown**: Handle browser cleanup issues gracefully (see implementation below)

#### Example WebAuthn Test Implementation

See `test/system/webauthn_sign_in_test.rb` for an implementation example. Key features include:

```ruby
# Robust teardown handling to recover from WebAuthn-related browser issues
def teardown
  begin
    super
  rescue Selenium::WebDriver::Error::NoSuchWindowError,
         Selenium::WebDriver::Error::InvalidArgumentError,
         NoMethodError => e
    puts "Rescued error during teardown: #{e.class} - #{e.message}"
  end
end

# Use fixed origins for testing
WebAuthn.configuration.origin = "https://example.com"
fake_client = WebAuthn::FakeClient.new("https://example.com")

# Focus on credential creation and verification
credential_hash = fake_client.create(challenge: credential_options.challenge)
credential = user.webauthn_credentials.create!(
  external_id: credential_hash["id"],
  public_key: "dummy_public_key_for_testing",
  nickname: "Test Key",
  sign_count: 0
)

# Verify the credential was saved correctly
assert_not_nil credential.id
assert user.reload.second_factor_enabled?
```

For more detailed information about WebAuthn implementation and testing, see [WebAuthn Guide](webauthn_guide.md).

## Best Practices

1. **Keep Tests Independent**: Each test should be able to run in isolation
2. **Clean Up After Tests**: Reset the application state after each test
3. **Use Page Objects**: Encapsulate page structure in reusable classes
4. **Avoid Sleep Statements**: Use explicit waits instead of arbitrary sleeps
5. **Test What Users Care About**: Focus on user-visible behavior rather than implementation details
6. **Write Resilient Selectors**: Use data attributes instead of CSS classes that might change
7. **Mock External Services**: Use WebMock or similar tools to avoid external dependencies
8. **Use Factories**: Create test data consistently with FactoryBot
9. **Handle Special Features Appropriately**: Use specialized approaches for WebAuthn and other platform-specific features
10. **Leverage Mocha for Mocking/Stubbing**: Mocha is configured (`mocha/minitest`) and available for creating mock objects and stubbing methods in unit or integration tests, or within helpers (e.g., see `test/support/attachment_test_helper.rb` for mocking ActiveStorage). Use it judiciously to isolate components or simplify test setup where appropriate, complementing full-stack system tests.

## References

- [Selenium Manager Documentation](https://www.selenium.dev/documentation/webdriver/drivers/selenium_manager/)
- [Rails System Testing Guide](https://guides.rubyonrails.org/testing.html#system-testing)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)
- [WebAuthn Testing Guide](https://github.com/cedarcode/webauthn-ruby/blob/master/README.md#testing)
