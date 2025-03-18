# Chrome System Testing Updates (2025)

This document provides updated guidance on our system testing approach, specifically regarding the transition from webdrivers gem to Selenium Manager for Chrome driver management.

## Key Changes (March 2025)

We have made the following significant changes to our system testing infrastructure:

1. **Removed webdrivers gem** - Previously relied on for managing ChromeDriver versions
2. **Adopted Selenium Manager** - Now using built-in driver management from Selenium 4.11+
3. **Simplified configuration** - Removed custom Chrome for Testing scripts and configurations
4. **Updated documentation** - This document supersedes previous guidance in system_test_chrome_fix.md and system_testing_chrome.md

## Current Approach

Our system tests now rely on Selenium Manager, which is built into Selenium WebDriver 4.11+. This approach:

1. Automatically detects the installed Chrome version
2. Downloads and manages the appropriate ChromeDriver version
3. Configures the environment for Selenium WebDriver
4. Requires minimal configuration in our codebase

## Using the Test Runner

For running system tests, use the standard Rails test runner:

```bash
bin/rails test test/system/path/to/test.rb
```

For all system tests:

```bash
bin/rails test:system
```

## Configuration

System tests are configured in `test/application_system_test_case.rb` with the standard Rails configuration:

```ruby
driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
```

This simple configuration works because Selenium Manager handles all the Chrome/ChromeDriver compatibility behind the scenes.

## Troubleshooting

### Browser Version Issues

If you encounter browser version compatibility issues:

1. Ensure you have a stable version of Chrome installed
2. Check the Selenium Manager logs by setting `SELENIUM_MANAGER_DEBUG=true`
3. Clear the Selenium Manager cache if necessary (typically in ~/.cache/selenium)

### Headless Testing

For headless testing (such as in CI environments), use:

```ruby
driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400]
```

### Process Management

The `test/support/capybara_config.rb` file includes process management code to clean up stray Chrome processes between test runs. This remains useful and has been retained.

## CI/CD Integration

Our GitHub Actions workflow uses `browser-actions/setup-chrome@v1` to ensure a consistent Chrome installation in the CI environment. This setup is compatible with Selenium Manager.

## Migration Reference

For details on the migration from webdrivers to Selenium Manager, see `doc/selenium_manager_migration.md`.

## References

- [Selenium Manager Documentation](https://www.selenium.dev/documentation/webdriver/drivers/selenium_manager/)
- [Rails System Testing Guide](https://guides.rubyonrails.org/testing.html#system-testing)
- [Capybara Documentation](https://github.com/teamcapybara/capybara)
