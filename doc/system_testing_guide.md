# System Testing Guide

This guide provides a comprehensive approach to debugging and fixing system test failures and errors in this application. It incorporates lessons learned from recent debugging efforts and outlines common issues, strategies, and best practices for effective system testing.

## Quick Start

### Running Tests with Minimal Noise (Recommended)

```bash
# Regular test run with minimal output (default)
rails test test/system/some_test.rb

# Or use the provided script
./bin/test-quiet test/system/some_test.rb
```

### Running Tests with Full Verbosity (For Debugging)

```bash
# Enable verbose logging when you need to debug
VERBOSE_TESTS=1 rails test test/system/some_test.rb

# Or use the provided script
./bin/test-verbose test/system/some_test.rb
```

## Test Log Noise Reduction

### Problem
System tests can generate extremely verbose logs that make it difficult to spot actual failures:
- Massive SQL statements from database operations
- ActiveRecord INSERT/UPDATE statements with full parameter lists
- ActiveStorage blob creation and upload logs
- Database seeding verbose output (clearing data, processing products)
- Custom debug logging from application concerns
- Browser connection management messages
- Route helper test warnings
- Favicon routing errors

### Solution
The test suite has been configured to minimize log noise by default:

#### Environment Configuration
- **Log Level**: Set to `:warn` by default (only errors and warnings shown)
- **ActiveRecord Logging**: Reduced verbosity unless `VERBOSE_TESTS=1`
- **ActiveStorage Logging**: Set to `:error` level
- **Query Logs**: Disabled verbose query logs and caller tracking

#### Database Strategy
- **Default**: Uses `transaction` strategy (fast, clean)
- **Fallback**: Use `USE_TRUNCATION=1` for tests requiring multiple DB connections

#### Seeding Output
- **Quiet Mode**: Only shows errors and completion messages
- **Verbose Mode**: Shows all processing steps when `VERBOSE_TESTS=1`

#### Browser Management
- **Connection Clearing**: Browser connection management messages only shown in verbose mode
- **Chrome Logging**: Reduced to fatal errors only unless `VERBOSE_TESTS=1`
- **Setup Messages**: Browser configuration messages suppressed by default

#### Route Helpers
- **Test Route Warnings**: Route helper tests only run when `VERBOSE_TESTS=1`
- **Favicon Handling**: Added silent favicon route to prevent routing errors

### Usage Examples

```bash
# Minimal output (recommended for development)
rails test test/system/admin/paper_applications_test.rb

# Full debugging output
VERBOSE_TESTS=1 rails test test/system/admin/paper_applications_test.rb

# Force truncation strategy if needed
USE_TRUNCATION=1 rails test test/system/some_test.rb
```

## Browser Configuration

### Current Setup
- **Primary Driver**: Cuprite (Chrome via CDP)
- **Fallback**: Selenium with Chrome
- **Configuration**: Located in `test/support/browsers/setup.rb`

### Key Features
- **Headless Mode**: Controlled by `HEADLESS` environment variable
- **Animation Disabled**: For faster, more reliable tests
- **Optimized Chrome Options**: Performance and stability focused
- **Error Recovery**: Built-in handling for common browser errors

### Browser Options
```bash
# Run with visible browser (for debugging)
HEADLESS=false rails test test/system/some_test.rb

# Add slowmo for debugging
SLOWMO=0.5 rails test test/system/some_test.rb
```

## Common Issues and Strategies

### 1. Authentication and Page Load Issues
Tests fail because the user is not properly signed in, or the page has not fully loaded before interaction.

**Strategy:**
- Use `system_test_sign_in(user)` from `SystemTestAuthentication`
- Use `wait_for_turbo` after navigation or Turbo Stream responses
- Verify authentication with `assert_authenticated_as(user)`
- Check for user-specific content (e.g., "Hello [User Name]", "Sign Out" link)

**Example:**
```ruby
def test_authenticated_user_can_access_dashboard
  user = create(:user)
  system_test_sign_in(user)
  
  visit admin_dashboard_path
  wait_for_turbo
  
  assert_authenticated_as(user)
  assert_text "Welcome to the Dashboard"
end
```

### 2. Element Not Found (`Capybara::ElementNotFound`)
Tests cannot find or interact with required elements.

**Strategy:**
- **Verify Selectors**: Use stable selectors (IDs, data attributes)
- **Check Visibility**: Use `visible: true` or `visible: :all` as needed
- **Add Waits**: Use `assert_selector 'selector', wait: N`
- **Use Safe Helpers**: `safe_click`, `safe_fill_in` from `SystemTestHelpers`

**Example:**
```ruby
# Instead of this:
find('#submit-button').click

# Use this:
assert_selector '#submit-button', wait: 5
safe_click('#submit-button')
```

### 3. JavaScript/Stimulus Controller Issues
Functionality driven by JavaScript doesn't behave as expected.

**Strategy:**
- Verify Stimulus controllers are registered in `app/javascript/controllers/index.js`
- Ensure correct `data-controller` and `data-target` attributes
- Add waits after JavaScript-triggered actions
- Use `wait_for_turbo` after Turbo Stream updates

**Example:**
```ruby
def test_dynamic_form_updates
  click_button "Add Item"
  wait_for_turbo
  
  assert_selector '[data-controller="dynamic-form"]'
  assert_selector '.new-item-field', count: 2
end
```

### 4. Database/Backend Errors
Tests trigger backend errors due to data handling issues.

**Strategy:**
- Examine test setup and factory usage
- Analyze backtraces to find error origins
- Review application code for query/data manipulation issues
- Ensure valid test data creation

### 5. Timing Issues / Race Conditions
Tests run faster than browser UI updates.

**Strategy:**
- Use explicit waits: `assert_selector 'selector', wait: N`
- Use `wait_for_turbo` after navigation
- Consider small `sleep` calls for complex async sequences
- Ensure background jobs complete if test depends on results

## Advanced Debugging

### Debug Tools Available

```ruby
# Take screenshot for visual debugging
take_screenshot("debug-state")

# Output current page state
debug_page  # Shows URL, path, and HTML summary

# Check authentication state
assert_authenticated_as(user)
assert_not_authenticated

# Scroll to elements before interaction
scroll_to_element('#target-element')
scroll_to_and_click('#button')
```

### Environment Variables for Debugging

```bash
# Show all test output
VERBOSE_TESTS=1

# Show authentication debug info
DEBUG_AUTH=true

# Run browser visibly
HEADLESS=false

# Add slowmo for step-by-step debugging
SLOWMO=1.0

# Use database truncation instead of transactions
USE_TRUNCATION=1
```

### Common Debug Workflow

1. **Run in Isolation**: Test single files to reduce noise
2. **Enable Verbose Mode**: `VERBOSE_TESTS=1` for full output
3. **Use Visual Browser**: `HEADLESS=false` to see what's happening
4. **Add Screenshots**: `take_screenshot` before failing assertions
5. **Check Page State**: `debug_page` to understand current state
6. **Verify Authentication**: Ensure user is properly signed in

## Test Helpers Reference

### SystemTestAuthentication
- `system_test_sign_in(user)` - Reliable user authentication
- `system_test_sign_out` - Clean sign out and session cleanup
- `assert_authenticated_as(user)` - Verify authentication state
- `with_authenticated_user(user) { ... }` - Scoped authentication

### SystemTestHelpers
- `safe_click(selector)` - Click with scrolling and error handling
- `safe_fill_in(selector, with: value)` - Fill with scrolling
- `wait_for_turbo` - Wait for Turbo navigation completion
- `take_screenshot(name)` - Save debugging screenshots
- `debug_page` - Output current page state

### CupriteTestBridge
- `enhanced_sign_in(user)` - Cuprite-optimized authentication
- `safe_interaction { ... }` - Error-resilient browser operations
- `wait_for_page_load` - Wait for complete page loading

## Best Practices

### Test Structure
```ruby
class MySystemTest < ApplicationSystemTestCase
  def setup
    # Minimal setup - let helpers handle browser configuration
    @user = create(:user)
  end

  def test_feature_works
    system_test_sign_in(@user)
    
    visit feature_path
    wait_for_turbo
    
    # Use safe helpers for interactions
    safe_fill_in('#input-field', with: 'test value')
    safe_click('#submit-button')
    
    # Assert expected outcomes
    assert_text 'Success message'
    assert_current_path success_path
  end
end
```

### Performance Tips
- Use `transaction` strategy (default) for faster tests
- Disable animations (already configured)
- Use stable selectors (IDs, data attributes)
- Minimize database seeding in individual tests
- Group related assertions to reduce page interactions

### Debugging Tips
- Start with minimal output, add verbosity only when needed
- Use screenshots liberally during development
- Test authentication separately from feature logic
- Verify page state before making assertions
- Use browser dev tools when running with `HEADLESS=false`

By following this guide and using the provided helpers, you can create reliable, maintainable system tests that effectively validate your application's functionality while minimizing debugging overhead.
