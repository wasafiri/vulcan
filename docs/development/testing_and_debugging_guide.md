# Testing and Debugging Guide

This comprehensive guide covers system testing, debugging, and fixing test failures in this Rails application. It consolidates lessons learned from debugging efforts and provides practical strategies for reliable testing.

## Quick Start

### Running Tests
```bash
# Minimal output (recommended)
rails test test/system/some_test.rb
./bin/test-quiet test/system/some_test.rb

# Full debugging output
VERBOSE_TESTS=1 rails test test/system/some_test.rb
./bin/test-verbose test/system/some_test.rb

# Special cases
USE_TRUNCATION=1 rails test        # Force truncation strategy
HEADLESS=false rails test          # Visual browser debugging
DEBUG_AUTH=true rails test         # Authentication debug info
```

## Test Configuration & Log Noise Reduction

### Environment Setup
The test suite minimizes log noise by default but can be made verbose for debugging:

- **Log Level**: `:warn` by default, `:debug` with `VERBOSE_TESTS=1`
- **Database Strategy**: `transaction` (fast) by default, `truncation` with `USE_TRUNCATION=1`
- **Browser**: Cuprite (Chrome via CDP) with optimized settings
- **Seeding**: Only shows errors and completion unless verbose mode
- **Auto-loading**: Test support files loaded automatically from `test/support/`

### Browser Configuration
- **Primary Driver**: Cuprite with Chrome
- **Headless Mode**: Controlled by `HEADLESS` environment variable
- **Performance**: Animations disabled, optimized Chrome options
- **Debug Options**: `SLOWMO=0.5` for step-by-step debugging

## Authentication in Tests

### For Unit & Controller Tests
```ruby
include AuthenticationTestHelper

# Sign in a user
sign_in(user)
# Or sign in with explicit controller cookie
sign_in_as(user)
# Or sign in with HTTP headers for integration tests
sign_in_with_headers(user)

# Verify the authentication
verify_authentication_state(user)

# Sign out
sign_out
```

### For System Tests
```ruby
include SystemTestAuthentication

# Sign in through UI
system_test_sign_in(user)

# For a specific code block
with_authenticated_user(user) do
  # Code that needs to run with this user
end

# Verify authentication state
assert_authenticated_as(user)

# Sign out
system_test_sign_out
```

### Authentication Core
- Uses `Thread.current[:test_user_id]` consistently across test types
- Shared `AuthenticationCore` module provides common methods
- Automatic session cleanup prevents test interference

## Attachment Mocking

### Recommended Approach
Use `AttachmentTestHelper#mock_attached_file` for consistent mocking:

```ruby
# Create a comprehensive mock for an attachment
income_proof_mock = mock_attached_file(
  filename: 'income.pdf',
  content_type: 'application/pdf',
  byte_size: 100.kilobytes,
  attached: true
)

# Stub the attachment on your model
application.stubs(:income_proof).returns(income_proof_mock)
application.stubs(:income_proof_attached?).returns(true)
```

### Factory Traits
```ruby
# Mocked attachments (fast, for unit tests)
create(:application, :with_mocked_income_proof)
create(:application, :with_all_mocked_attachments)

# Real attachments (for integration tests)
create(:application, :with_real_income_proof)
create(:application, :with_all_real_attachments)
```

### When to Use Each
- **Mocked attachments**: Unit tests, performance-sensitive tests, when you only care about presence/absence
- **Real attachments**: Integration tests, when testing file processing, when testing ActiveStorage behavior

## Common Issues & Solutions

### 1. Authentication Issues
**Problem**: User not properly signed in or session state issues.

**Solutions**:
- Use `system_test_sign_in(user)` for system tests
- Use `enhanced_sign_in(user)` for Cuprite-specific tests
- Verify with `assert_authenticated_as(user)`
- Add `wait_for_turbo` after navigation

### 2. Element Not Found (`Capybara::ElementNotFound`)
**Problem**: Tests can't find or interact with elements.

**Solutions**:
- Use stable selectors (IDs, data attributes)
- Use `visible: :all` for conditionally hidden elements
- Add explicit waits: `assert_selector 'selector', wait: 5`
- Use safe helpers: `safe_click`, `safe_fill_in`

### 3. JavaScript/Stimulus Issues
**Problem**: JavaScript functionality doesn't work as expected.

**Solutions**:
- Verify Stimulus controllers are registered
- Check `data-controller` and `data-target` attributes
- Add waits after JavaScript actions
- Use `wait_for_turbo` for Turbo Stream updates

### 4. Timing Issues & Race Conditions
**Problem**: Tests run faster than UI updates.

**Solutions**:
- Use explicit waits with appropriate timeouts
- Wait for Turbo navigation completion
- Ensure background jobs complete before assertions
- Use `sleep` sparingly for complex async sequences

### 5. Database/Backend Errors
**Problem**: Tests trigger backend errors due to data issues.

**Solutions**:
- Examine test setup and factory usage
- Analyze backtraces for error origins
- Ensure valid test data creation
- Check for proper thread-local context setup

## JavaScript Error Debugging

### Ferrum::JavaScriptError Resolution
**Problem**: `RangeError: Maximum call stack size exceeded` from `getComputedStyle` recursion.

**Root Cause**: Chart.js global import causing style computation recursion in headless browser.

**Solution Applied**:
1. Temporarily removed Chart.js global import from `application.js`
2. Modified `chart_controller.js` to handle missing Chart.js gracefully
3. Rebuilt JavaScript bundles with asset precompilation
4. Fixed dependent selector radio button logic

**Files Modified**:
- `app/javascript/application.js` - Commented Chart.js import
- `app/javascript/controllers/chart_controller.js` - Added availability check
- `app/javascript/controllers/dependent_selector_controller.js` - Fixed selection logic

## Application Architecture Context

### Paper Application Form Design
The paper application form uses coordinated Stimulus controllers:

1. **PaperApplicationController** - Main coordinator, income validation
2. **DependentFieldsController** - Manages dependent fields and address copying
3. **ApplicantTypeController** - Handles adult vs dependent views
4. **DocumentProofHandlerController** - Manages proof acceptance/rejection
5. **GuardianSelectionController** - Coordinates search and selection

### Thread-Local Context
Uses `Thread.current[:paper_application_context]` to bypass validations:
- Critical for `ProofConsistencyValidation` and `ProofManageable` concerns
- Must be set during paper form processing with `PaperApplicationContext.wrap`

### Guardian/Dependent Data Model
- Uses `GuardianRelationship` model for explicit relationships
- `Application` has `managing_guardian_id` for dependent applications
- Database constraints ensure data integrity

## Test Configuration

### Environment Setup
- **Log Level**: `:warn` by default, `:debug` with `VERBOSE_TESTS=1`
- **Database Strategy**: `transaction` (fast) by default, `truncation` with `USE_TRUNCATION=1`
- **Browser**: Cuprite (Chrome via CDP) with optimized settings
- **Auto-loading**: Test support files loaded automatically from `test/support/`

### Browser Configuration
- **Primary Driver**: Cuprite with Chrome
- **Headless Mode**: Controlled by `HEADLESS` environment variable
- **Performance**: Animations disabled, optimized Chrome options
- **Debug Options**: `SLOWMO=0.5` for step-by-step debugging

## Test Helpers Reference

### Authentication
- `system_test_sign_in(user)` - Standard system test authentication
- `enhanced_sign_in(user)` - Cuprite-optimized authentication
- `assert_authenticated_as(user)` - Verify authentication state
- `system_test_sign_out` - Clean session cleanup

### Interaction Helpers
- `safe_click(selector)` - Click with scrolling and error handling
- `safe_fill_in(selector, with: value)` - Fill with scrolling
- `wait_for_turbo` - Wait for Turbo navigation completion
- `scroll_to_element(selector)` - Scroll element into view

### Debugging Tools
- `take_screenshot(name)` - Visual debugging screenshots
- `debug_page` - Output current page state and URL
- `clear_pending_connections` - Clear browser connection issues

## Best Practices

### Test Structure
```ruby
class MySystemTest < ApplicationSystemTestCase
  def setup
    @user = create(:user)
  end

  def test_feature_works
    system_test_sign_in(@user)
    visit feature_path
    wait_for_turbo
    
    safe_fill_in('#input-field', with: 'test value')
    safe_click('#submit-button')
    
    assert_text 'Success message'
    assert_current_path success_path
  end
end
```

### Performance & Reliability
- Use `transaction` strategy for faster tests
- Prefer stable selectors (IDs, data attributes)
- Test complete data flow from form to database
- Verify all models updated during operations
- Use explicit waits instead of arbitrary sleeps
- Test different user scenarios (self vs guardian applications)

### Debugging Workflow
1. Run tests in isolation to reduce noise
2. Enable verbose mode: `VERBOSE_TESTS=1`
3. Use visual browser: `HEADLESS=false`
4. Add screenshots before failing assertions
5. Verify authentication and page state
6. Check browser dev tools for JavaScript errors

## Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| `VERBOSE_TESTS` | Enable full debug output | `VERBOSE_TESTS=1` |
| `USE_TRUNCATION` | Force database truncation | `USE_TRUNCATION=1` |
| `HEADLESS` | Control browser visibility | `HEADLESS=false` |
| `SLOWMO` | Add delays for debugging | `SLOWMO=1.0` |
| `DEBUG_AUTH` | Authentication debug info | `DEBUG_AUTH=true` |

## Major Bug Fixes & Lessons Learned

### Authentication Helper Consolidation (2025-05-17)
**Issues Fixed**:
1. Session leakage between tests in parallel environments
2. Integration test header handling across multiple requests
3. Inconsistent authentication state management

**Solutions**:
- Created shared `AuthenticationCore` module
- Standardized on `Thread.current[:test_user_id]`
- Improved session cleanup with proper cookie and session clearing
- Enhanced error messages and debug logging

### Guardian Relationship Migration (2025-05-25)
**Issues Fixed**:
1. Text assertion mismatches in guardian proof review
2. Application creation failures with new schema
3. Incorrect association usage in relationship creation

**Solutions**:
- Updated UI text assertions to match new terminology
- Fixed GuardianRelationship creation to use column names (`guardian_id`, `dependent_id`) not association names
- Enhanced test coverage for guardian functionality

### Address Information Bug (2025-05-26)
**Critical Bug**: Address information entered during application creation wasn't being saved.

**Root Cause**: `extract_address_attributes` method existed but wasn't called in controller.

**Fix**: Added address attribute extraction and merging in `ConstituentPortal::ApplicationsController#create`

**Impact**: Prevented data loss for thousands of applications and improved proof review context.

### User Model Test Fixes (2025-01-25)
**Issues Fixed**:
1. Private method access errors
2. Phone number and email uniqueness conflicts
3. Hardcoded test data conflicts

**Solutions**:
- Used `send()` for private method testing
- Generated unique phone numbers and emails
- Updated assertions to match dynamic test data

## Best Practices

### Test Structure
```ruby
class MySystemTest < ApplicationSystemTestCase
  def setup
    @user = create(:user)
  end

  def test_feature_works
    system_test_sign_in(@user)
    visit feature_path
    wait_for_turbo
    
    safe_fill_in('#input-field', with: 'test value')
    safe_click('#submit-button')
    
    assert_text 'Success message'
    assert_current_path success_path
  end
end
```

### Performance & Reliability
- Use `transaction` strategy for faster tests
- Prefer stable selectors (IDs, data attributes)
- Test complete data flow from form to database
- Verify all models updated during operations
- Use explicit waits instead of arbitrary sleeps
- Test different user scenarios (self vs guardian applications)

### Debugging Workflow
1. Run tests in isolation to reduce noise
2. Enable verbose mode: `VERBOSE_TESTS=1`
3. Use visual browser: `HEADLESS=false`
4. Add screenshots before failing assertions
5. Verify authentication and page state
6. Check browser dev tools for JavaScript errors

### Common Patterns
- **Hidden Elements**: Use `visible: :all` and JavaScript to make visible
- **Turbo Frames**: Use `within('#id')` not `within_frame`
- **Form Interactions**: Sequence dependent field interactions properly
- **Guardian Selection**: Handle both search results and direct selection
- **Address Fields**: Always verify persistence to user model 