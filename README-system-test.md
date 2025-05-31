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

# Run with specific tags (if implemented)
bin/rails test:system -- --tag=authentication
```

## Test Environment Setup

### Local Development

For local development, system tests use headless Chrome with the following configuration:

1. **Browser Driver**: Headless Chrome
2. **Window Size**: 1400x1400
3. **Default Wait Time**: 5 seconds
4. **Authentication Helpers**: Consolidated authentication system with `AuthenticationCore` module

### CI Environment

When running in CI (GitHub Actions), the system tests use a similar configuration with optimized settings:

1. **Browser**: Chrome (installed via browser-actions/setup-chrome@v1)
2. **Network Settings**: Binds to all interfaces ('0.0.0.0')
3. **Default Wait Time**: 10 seconds (increased for CI stability)
4. **Enhanced Error Handling**: Improved session management and form detection

## Authentication Testing Infrastructure

### Consolidated Authentication Helpers

The test suite uses a unified authentication system:

- **`AuthenticationCore` module**: Shared authentication logic across test types
- **Progressive form detection**: Enhanced sign-in form field detection
- **Session leak prevention**: Proper session cleanup between tests
- **Header handling**: Consistent authentication header management

### Test Helper Usage

```ruby
# In system tests
include AuthenticationTestHelper

def setup
  @user = create(:user)
end

test "authenticated user can access dashboard" do
  sign_in_as(@user)
  visit dashboard_path
  assert_text "Welcome"
end
```

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

3. **Authentication failures**: Use the consolidated authentication helpers:
   ```ruby
   # Instead of manual form filling
   sign_in_as(@user)
   
   # For specific authentication flows
   sign_in_with_2fa(@user, method: :totp)
   ```

4. **Random failures in CI**: Add debug output and increase timeouts:
   ```ruby
   puts page.html # Print current page HTML
   take_screenshot('debug-screenshot') # Capture visual state
   ```

### Marking Tests to Skip in CI

Some tests may need to be skipped in CI environments. Use the `ci_skip` metadata:

```ruby
test "feature that doesn't work in CI", ci_skip: true do
  # Test code
end
```

### Test Data Management

- **Factories**: Use FactoryBot for consistent test data creation
- **Traits**: Leverage factory traits for specific test scenarios
- **Cleanup**: Proper test data cleanup between tests
- **Mocking**: Use `with_mocked_attachments` for file upload tests

## Notes on Browser Testing Infrastructure

The application uses:

1. **Capybara**: For browser automation with enhanced configuration
2. **Selenium WebDriver**: For browser control with Chrome for Testing
3. **Enhanced Helpers**: Consolidated authentication and form interaction helpers
4. **Screenshot Support**: Automated screenshot capture for debugging

The configuration can be found in:
- `config/initializers/capybara.rb`
- `test/application_system_test_case.rb`
- `test/support/authentication_test_helper.rb`

## Current Test Status

### Passing Test Categories
- Authentication flows (sign-in, 2FA setup)
- Guardian relationship management
- Application creation and submission
- Admin interface interactions
- Proof review workflows

### Known Issues
- Some system tests may experience connection timeouts in CI
- Browser environment configuration requires ongoing maintenance
- Complex multi-step workflows may need additional wait time adjustments
