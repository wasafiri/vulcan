# Chrome for Testing Setup Guide

This document outlines the process for setting up and troubleshooting Chrome for Testing in the system test suite. 

## Overview

System tests in Rails provide end-to-end testing capabilities using a real browser. We use Chrome for Testing, which is a version of Chrome designed specifically for automated testing. This provides several advantages:

1. No auto-updates, ensuring consistent test results
2. Isolated from regular Chrome instances
3. Better compatibility with Selenium/Capybara
4. Support for headless mode
5. No interference with your regular Chrome browser (you can browse normally during test runs)

## Initial Setup

We've added the following improvements to make system testing more reliable:

1. Added the webdrivers gem for automatic ChromeDriver management
2. Enhanced the setup script to properly handle Chrome for Testing installations 
3. Added handling for macOS quarantine attributes to prevent security blocks
4. Implemented version matching to ensure Chrome and ChromeDriver are compatible
5. Added automatic timeout detection to prevent hanging tests

## Using the Test Runners

### Standard Rails Test Runner

For simple tests, you can use the standard Rails test runner:

```bash
bin/rails test test/system/path/to/test.rb
```

### Enhanced Test Runner

For tests that might encounter stability issues, use our enhanced runner:

```bash
bin/run-test test/system/path/to/test.rb
```

The enhanced runner automatically:
- Kills any hanging Chrome processes
- Cleans up temporary directories
- Sets up Chrome for Testing with the correct permissions
- Provides detailed debugging information
- Implements timeouts to prevent hanging tests

## Troubleshooting Common Issues

### Authentication Problems

System tests may fail due to authentication issues. Check:
- Session management in the tests
- Cookie handling
- TEST_USER_ID environment variable

### Flaky Tests

If tests pass sometimes and fail other times:
- Use explicit waits with `wait_for_turbo`
- Add timeout protection with the `with_timeout` helper
- Ensure selectors are resilient to DOM changes

### Browser Hanging

If the browser process hangs during tests:
1. Use the `bin/run-test` script which includes timeout protection
2. Check screenshots saved to tmp/capybara
3. Review logs in log/test.log and tmp/chromedriver.log

### macOS Specific Issues

On macOS, Chrome for Testing may be blocked by Gatekeeper. We've added automatic handling for this, but you can manually fix it with:

```bash
xattr -cr "path/to/chrome/binary"
```

## Configuration Files

The key files for Chrome for Testing setup are:

1. **bin/setup-test-browser**: Sets up Chrome for Testing with proper permissions
2. **bin/run-test**: Enhanced test runner with debugging capabilities
3. **config/initializers/capybara.rb**: Configures Capybara to use Chrome for Testing
4. **test/test_helper.rb**: Includes webdrivers configuration

## Best Practices

1. Use explicit timeouts for potentially slow operations
2. Add debugging information to help diagnose failures
3. Take screenshots at key points in test execution
4. Check console logs for JavaScript errors
5. Keep Chrome and ChromeDriver versions in sync
6. Use a dedicated user profile for testing
7. Our process management now:
   - Uses precise pattern matching to only target Chrome for Testing processes
   - Implements graceful shutdown with SIGTERM before force-killing
   - Provides detailed debugging output about running processes
   - Verifies preservation of your regular Chrome browser during tests
   - Includes more reliable process detection on different platforms

## References

- [Chrome for Testing Documentation](https://developer.chrome.com/blog/chrome-for-testing/)
- [WebDrivers Gem Documentation](https://github.com/titusfortner/webdrivers)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)
- [Rails System Testing Guide](https://guides.rubyonrails.org/testing.html#system-testing)
