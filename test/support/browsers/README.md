# [DEPRECATED] Chrome for Testing Integration

> **Note**: This directory contains the previous implementation for using Chrome for Testing in our system tests.
> We have now transitioned to using **standard Chrome with Selenium Manager** for a simpler and more reliable setup.
> This directory is kept for reference only and will be removed in a future release.

## New System Testing Approach

Our system tests now use:

1. **Standard Chrome**: We use the regular Chrome browser (or headless Chrome) instead of Chrome for Testing
2. **Selenium Manager**: Automatically handles downloading and managing the appropriate ChromeDriver version
3. **Simplified Configuration**: Configuration is in `test/support/capybara_config.rb`

## Benefits of the New Approach

- **Simpler Setup**: No need to download separate Chrome for Testing binaries
- **Automatic Compatibility**: Selenium Manager handles browser-driver compatibility
- **Better Reliability**: Fewer moving parts and dependencies
- **Easier Maintenance**: Less custom code to maintain

## Running System Tests

To run system tests:

1. Use `bin/rails test:system` to run all system tests
2. Use `bin/run-test test/system/some_test.rb` for enhanced debugging

## If You're Encountering Issues

If you're experiencing issues with system tests:

1. Make sure you have Chrome installed on your system
2. Try running with enhanced debugging: `bin/run-test test/system/some_test.rb`
3. Check that Selenium Manager is working by looking for log messages about driver downloads
