# System Testing Guide

This comprehensive guide explains how to run and maintain system tests in the MAT Vulcan application using Selenium WebDriver and Chrome.

## Table of Contents
1. [Overview](#overview)
2. [Current Architecture](#current-architecture)
3. [Running Tests](#running-tests)
4. [Configuration Details](#configuration-details)
5. [Headless Testing](#headless-testing)
6. [Browser and Driver Management](#browser-and-driver-management)
7. [CI/CD Integration](#cicd-integration)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

## Overview

System tests allow us to verify the application's functionality from the user's perspective by automating browser interactions. Our system tests use:

- **Rails System Testing**: Built on Rails' integration with Capybara
- **Selenium WebDriver**: For browser automation
- **Chrome**: As the default browser for testing
- **Selenium Manager**: For automatic driver management (since March 2025)

## Current Architecture

Our system testing architecture consists of:

1. **Selenium WebDriver**: Controls the Chrome browser
2. **Capybara**: Provides a user-friendly DSL for browser interaction
3. **Selenium Manager**: Manages ChromeDriver versions and compatibility
4. **Minitest**: The testing framework

This architecture provides reliable end-to-end testing of the application with minimal configuration.

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
  driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
  
  # Helper methods and setup can be defined here
end
```

Additional configuration that improves the testing experience is in `test/support/capybara_config.rb`, which:

- Sets up process management to clean up stray Chrome processes
- Configures timeouts and retries for improved stability
- Provides helper methods for common test operations

## Headless Testing

For CI environments or when you don't need to see the browser visually, use headless mode:

### Configuring Headless Mode

In `test/application_system_test_case.rb`:

```ruby
driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
```

Or for a specific test case:

```ruby
class MyHeadlessTest < ApplicationSystemTestCase
  setup do
    driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
  end
  
  # test cases...
end
```

## Browser and Driver Management

As of March 2025, we use Selenium Manager for browser driver management, which:

1. Automatically detects the installed Chrome version
2. Downloads and manages the appropriate ChromeDriver version
3. Configures the environment for Selenium WebDriver
4. Requires minimal configuration in our codebase

This approach has several advantages:
- **Better Chrome version compatibility** - Selenium Manager handles version matching between Chrome and ChromeDriver more reliably
- **Simplified configuration** - No need for explicit driver version pinning or cache management
- **Future-proof** - Direct support from the Selenium project ensures ongoing compatibility
- **Elimination of custom scripts** - We no longer need custom Chrome for Testing setup scripts

## CI/CD Integration

Our GitHub Actions workflow uses `browser-actions/setup-chrome@v1` to ensure a consistent Chrome installation in the CI environment. This setup is compatible with Selenium Manager and provides reliable test execution in automated environments.

```yaml
# Example GitHub Actions configuration
steps:
  - uses: browser-actions/setup-chrome@v1
  - name: Run system tests
    run: bin/rails test:system
```

## Troubleshooting

### Common Issues and Solutions

#### Browser Version Issues

If you encounter browser version compatibility issues:

1. Ensure you have a stable version of Chrome installed
2. Check the Selenium Manager logs: `SELENIUM_MANAGER_DEBUG=true bin/rails test:system`
3. Clear the Selenium Manager cache: `rm -rf ~/.cache/selenium`

#### Test Flakiness

For flaky tests (tests that inconsistently pass or fail):

1. Increase wait times for asynchronous operations
2. Add explicit waits using Capybara's `have_content` or similar matchers
3. Use retries for network-dependent operations

#### Stale Element References

When elements become stale during a test:

1. Re-fetch elements before interacting with them
2. Use Capybara's built-in retry mechanism with finders
3. Use explicit waits for page changes

#### Clearing the Cache

If you need to reset the Selenium Manager state:

```bash
rm -rf ~/.cache/selenium
```

### Debugging Tips

1. **Check the Logs**: Rails logs capture JavaScript errors and Selenium exceptions
2. **Use Screenshots**: Capybara can save screenshots at failure points
3. **Enable Verbose Logging**: Set `SELENIUM_MANAGER_DEBUG=true` for detailed driver information
4. **Visual Debugging**: Comment out headless mode to see the browser actions

## Best Practices

1. **Keep Tests Independent**: Each test should be able to run in isolation
2. **Clean Up After Tests**: Reset the application state after each test
3. **Use Page Objects**: Encapsulate page structure in reusable classes
4. **Avoid Sleep Statements**: Use explicit waits instead of arbitrary sleeps
5. **Test What Users Care About**: Focus on user-visible behavior rather than implementation details
6. **Write Resilient Selectors**: Use data attributes instead of CSS classes that might change
7. **Mock External Services**: Use WebMock or similar tools to avoid external dependencies
8. **Use Factories**: Create test data consistently with FactoryBot

## References

- [Selenium Manager Documentation](https://www.selenium.dev/documentation/webdriver/drivers/selenium_manager/)
- [Rails System Testing Guide](https://guides.rubyonrails.org/testing.html#system-testing)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)
