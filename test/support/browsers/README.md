# Chrome for Testing Integration

This directory contains the implementation for using Chrome for Testing in our system tests. Chrome for Testing is a special version of Chrome designed specifically for automated testing.

## Benefits

- **No auto-update**: Unlike regular Chrome, Chrome for Testing doesn't auto-update, providing consistent results across test runs.
- **Version matching**: We download matching ChromeDriver and Chrome versions, eliminating version compatibility issues.
- **Official support**: This is the officially recommended approach by the Chrome team for automated testing.

## How It Works

The system is divided into four components:

1. **Version Management** (`version.rb`): Defines which Chrome for Testing version to use and handles platform-specific settings.
2. **Path Management** (`paths.rb`): Manages the paths for downloaded binaries and ensures directories exist.
3. **Downloader** (`downloader.rb`): Downloads Chrome for Testing and ChromeDriver from Google's servers.
4. **Setup** (`setup.rb`): Configures Capybara to use the downloaded binaries.

## Updating Chrome for Testing Version

To update the Chrome for Testing version:

1. Edit `version.rb` and update the `CHROME_VERSION` constant.
2. Run any test to trigger the download of the new version.

```ruby
# Example: Update to a new version
module TestBrowsers
  module Version
    # Update this to a newer version
    CHROME_VERSION = "135.0.6800.0"
    # ...
  end
end
```

## Troubleshooting

If you encounter issues with the Chrome for Testing setup:

1. **Manual cleanup**: Remove the `tmp/test_browsers` directory to force a fresh download.
2. **Version issues**: Check that the specified version exists on Google's servers.
3. **Permission issues**: Ensure the downloaded binaries have execute permissions.

## Finding Available Versions

You can find available Chrome for Testing versions at:
https://googlechromelabs.github.io/chrome-for-testing/

## Chrome for Testing vs. Using webdrivers gem

This implementation replaces our previous approach using the webdrivers gem:

- **webdrivers gem**: Automatically detected Chrome version and downloaded a matching ChromeDriver. This worked well for regular Chrome versions but failed with dev/canary builds.
- **Chrome for Testing**: Downloads both Chrome and ChromeDriver, ensuring they're always compatible. Works reliably for testing regardless of what Chrome version is installed on the system.
