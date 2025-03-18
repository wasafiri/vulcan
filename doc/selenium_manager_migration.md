# Migrating from Webdrivers to Selenium Manager

## Background

This document outlines our migration from the webdrivers gem to Selenium Manager for handling browser drivers in system tests. As of March 2025, we're implementing this change to align with best practices recommended by the Selenium and Webdrivers teams.

## Why Migrate?

The webdrivers gem author has explicitly recommended transitioning to Selenium Manager for projects using Selenium 4.11+:

> With Google's new Chrome for Testing project, and Selenium's new Selenium Manager feature, what is required of this gem has changed. If you can update to the latest version of Selenium (4.11+), please do so and stop requiring this gem.

Since we're already using Selenium 4.29.1, the migration makes sense for several reasons:

1. **Better Chrome version compatibility** - Selenium Manager handles version matching between Chrome and ChromeDriver more reliably
2. **Simplified configuration** - No need for explicit driver version pinning or cache management
3. **Future-proof** - Direct support from the Selenium project ensures ongoing compatibility
4. **Elimination of custom scripts** - We can remove our custom Chrome for Testing setup scripts

## How Selenium Manager Works

Selenium Manager is built into Selenium WebDriver 4.11+ and handles driver management automatically:

1. It detects the installed browser version (Chrome, Firefox, Edge, etc.)
2. It downloads the appropriate driver version that matches the browser
3. It configures the environment for Selenium WebDriver to use the correct driver
4. It manages this process transparently, without requiring explicit configuration

This is a significant improvement over the manual configuration we previously needed with webdrivers.

## Migration Plan

The following files need changes:

### 1. Gemfile

Remove the webdrivers gem from the test group:

```ruby
# REMOVE this line
gem "webdrivers", "~> 5.2.0"
```

Run `bundle update` after this change.

### 2. Files Removed

The following files have been completely removed from the codebase:

- `bin/test-with-chrome-for-testing` - Previously used to run tests with Chrome for Testing binaries
- `bin/test-chrome-114` - Specifically targeted ChromeDriver version 114 for testing
- `bin/fix-chrome-test` - Fixed Chrome/ChromeDriver compatibility issues

Additionally, the following file was replaced with an informational stub:

- `config/initializers/webdrivers.rb` - Previously configured the webdrivers gem

### 3. Test Helper Update

In `test/test_helper.rb`, remove the webdrivers-specific code:

```ruby
# REMOVE these lines
require "webdrivers" # Load webdrivers for Chrome/ChromeDriver management

# Configure Webdrivers gem for system tests
Webdrivers.cache_time = 0 # Force driver update on every run
Webdrivers.install_dir = File.join(Dir.home, '.webdrivers')
cached_driver = File.join(Webdrivers.install_dir, "chromedriver")
File.delete(cached_driver) if File.exist?(cached_driver)
Webdrivers::Chromedriver.update
```

### 4. Update bin/direct-test

The file `bin/direct-test` will need to be updated to remove the Chrome for Testing-specific configuration and the temporary Ruby file for setting ChromeDriver version.

### 5. Simplify capybara_config.rb

While most of the Capybara configuration in `test/support/capybara_config.rb` is still useful for process management, we should review it for any webdrivers-specific code.

### 6. System Test Configuration

The system test configuration in `test/application_system_test_case.rb` can remain as is:

```ruby
driven_by :selenium, using: :chrome, screen_size: [1400, 1400]
```

## Testing the Migration

After implementing these changes:

1. Run a simple system test to verify it works:
   ```
   bin/rails test test/system/sample_system_test.rb
   ```

2. If successful, run all system tests:
   ```
   bin/rails test:system
   ```

## Troubleshooting

### Common Issues

1. **Driver not found error**
   - This can happen if Selenium Manager can't download the driver
   - Solution: Manually clear the Selenium Manager cache (typically in ~/.cache/selenium)

2. **Incompatible version error**
   - If you have an unusual Chrome version, Selenium Manager might not find a compatible driver
   - Solution: Install a stable Chrome version or use Chrome for Testing from browser-actions/setup-chrome

3. **Permission issues**
   - Selenium Manager might have trouble setting executable permissions
   - Solution: Manually ensure the driver has executable permissions

### Verifying Selenium Manager is Working

You can confirm Selenium Manager is being used by enabling debug logging:

```bash
export SELENIUM_MANAGER_DEBUG=true
bin/rails test test/system/sample_system_test.rb
```

This will show Selenium Manager's operations in the logs.

## CI/CD Considerations

Our GitHub Actions workflow already uses browser-actions/setup-chrome@v1 which is compatible with Selenium Manager. No changes should be needed there.

## References

- [Selenium Documentation](https://www.selenium.dev/documentation/webdriver/drivers/selenium_manager/)
- [Webdrivers Gem README](https://github.com/titusfortner/webdrivers)
- [Chrome for Testing Documentation](https://developer.chrome.com/blog/chrome-for-testing)
