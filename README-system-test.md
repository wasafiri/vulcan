# System Testing Setup

This document outlines the setup for system tests in the application, including browser configurations for local development and CI environments.

## Running System Tests

System tests can be run using the following commands:

```bash
# Run all tests including system tests
bin/rails test:all

# Run only system tests
bin/rails test:system

# Run a specific system test file
bin/rails test test/system/admin/medical_certification_test.rb
```

## Test Environment Setup

### Local Development

For local development, system tests use headless Chrome with the following configuration:

1. **Browser Driver**: Headless Chrome
2. **Window Size**: 1400x1400
3. **Default Wait Time**: 5 seconds

### CI Environment

When running in CI (GitHub Actions), the system tests use a similar configuration with optimized settings:

1. **Browser**: Chrome (installed via browser-actions/setup-chrome@v1)
2. **Network Settings**: Binds to all interfaces ('0.0.0.0')
3. **Default Wait Time**: 10 seconds (increased for CI stability)

## Troubleshooting

### Common Issues

1. **Tests hanging**: Check for orphaned Chrome processes and kill them:
   ```bash
   # Only target Chrome for Testing, not regular Chrome
   pkill -TERM -f 'Chrome for Testing'  # Try graceful shutdown first
   sleep 1
   pkill -f 'Chrome for Testing'        # Then force if needed
   ```

2. **Element not found**: Increase wait time by using explicit waits:
   ```ruby
   using_wait_time(10) do
     # Your test code here
   end
   ```

3. **Random failures in CI**: Add debug output and increase timeouts:
   ```ruby
   puts page.html # Print current page HTML
   ```

### Marking Tests to Skip in CI

Some tests may need to be skipped in CI environments. Use the `ci_skip` metadata:

```ruby
test "feature that doesn't work in CI", ci_skip: true do
  # Test code
end
```

## Notes on Browser Testing Infrastructure

The application uses:

1. **Capybara**: For browser automation
2. **Selenium WebDriver**: For browser control
3. **Chrome for Testing**: For consistent browser behavior

The configuration can be found in:
- `config/initializers/capybara.rb`
- `test/application_system_test_case.rb`
