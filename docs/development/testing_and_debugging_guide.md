# Testing and Debugging Guide

This comprehensive guide covers system testing, debugging, and fixing test failures in this Rails application. It consolidates lessons learned from debugging efforts and provides practical strategies for reliable testing.

## ✅ Recent Test Consolidation Success (December 2025)

The application test suite underwent successful consolidation with **100% test success rate achieved**:

- **76 application tests passing** (319 assertions, 0 failures)
- **16 test files consolidated** with shared helper modules
- **110+ lines of duplicate code eliminated**
- **Authentication patterns standardized** across integration tests
- **FPL calculations corrected** to proper 400% Federal Poverty Level

See: [`test_consolidation_strategy.md`](test_consolidation_strategy.md) for complete details.

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

# Sign in with explicit controller method
sign_in_for_controller_test(user)
# Or use the shorter alias
sign_in_as(user)

# Verify the authentication
verify_authentication_state(user)

# Sign out
sign_out
```

### For Integration Tests (ActionDispatch::IntegrationTest)
**Important**: Use `sign_in_for_integration_test(user)` for integration tests to avoid authentication issues:

```ruby
include AuthenticationTestHelper

# Correct pattern for integration tests - use explicit method
sign_in_for_integration_test(@user)
# Or use the shorter alias
sign_in_with_headers(@user)

# Verify authentication state
assert_authenticated(@user)

# AVOID: The flexible sign_in method was removed due to priority detection bugs
# sign_in(@user)  # DON'T use - removed in favor of explicit methods
```

### For Unit/Other Tests
```ruby
include AuthenticationTestHelper

# Sign in for unit tests (just sets Current.user)
sign_in_for_unit_test(user)
# Or use the shorter alias
update_current_user(user)
```

### Why Explicit Methods?
The original flexible `sign_in(user)` method used automatic detection to choose between controller and integration methods, but this caused bugs:
- After HTTP requests, `@controller` would be set in integration tests
- Priority logic would incorrectly choose controller method over integration method
- This caused `@test_user_id` not to update properly for subsequent authentications

**Solution**: Use explicit methods that clearly indicate the test context and avoid magical detection.

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

## Shared Test Helpers

### ✅ FPL Policy Helpers (Globally Available)
Use the centralized FPL policy setup for consistent test data:

```ruby
# Available in all tests via global inclusion
setup do
  setup_fpl_policies  # Creates standardized policies with 400% modifier
end

# Manual usage (not usually needed)
include FplPolicyHelpers
setup_fpl_policies
```

**FPL Values Set by Helper:**
- 1 person: $15,000 (400% of $3,750 base)
- 2 people: $20,000 (400% of $5,000 base)
- 3 people: $25,000 (400% of $6,250 base)
- etc.
- Modifier: 400% (not 200% - this was corrected during consolidation)

### ✅ Paper Application Context Helpers (Globally Available)
Use the centralized context management for paper application tests:

```ruby
# Available in all tests via global inclusion
setup do
  setup_paper_application_context  # Sets Current.paper_context = true
end

teardown do
  teardown_paper_application_context  # Calls Current.reset
end

# Manual usage (not usually needed)
include PaperApplicationContextHelpers
```

**Why This Matters:**
- Bypasses `ProofConsistencyValidation` and `ProofManageable` validation concerns
- Essential for testing paper application workflows
- Prevents validation errors that only apply to online submissions

### Module Locations
```
test/support/
├── fpl_policy_helpers.rb              # FPL policy setup
├── paper_application_context_helpers.rb  # Current attributes context
└── authentication_test_helper.rb      # Authentication methods
```

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

***Use the proper sign-in helpers!***

- ✅ **For Integration Tests**: Use `sign_in_for_integration_test(user)` or `sign_in_with_headers(user)`
- ✅ **For Controller Tests**: Use `sign_in_for_controller_test(user)` or `sign_in_as(user)`
- ✅ **For Unit Tests**: Use `sign_in_for_unit_test(user)` or `update_current_user(user)`
- ✅ **Include Helper**: Ensure `include AuthenticationTestHelper` in test class
- ✅ **Factory Usage**: Use `:constituent` factory instead of `:user, :constituent`
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
- ✅ **Use Shared Helpers**: Leverage `setup_fpl_policies` and `setup_paper_application_context`
- Check for proper Current attributes context setup

### 6. FPL Threshold Issues
**Problem**: Tests fail due to incorrect Federal Poverty Level calculations.

**Solutions**:
- ✅ **Use Shared Helper**: Always use `setup_fpl_policies` for consistent 400% modifier
- ✅ **Check Values**: Verify tests expect 400% not 200% of poverty level
- ✅ **Income Calculations**: Ensure test income values align with 400% thresholds

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

### Current Attributes Context
Uses `Current.paper_context` to bypass validations:
- Critical for `ProofConsistencyValidation` and `ProofManageable` concerns
- Must be set during paper form processing
- ✅ **Now managed by shared helper**: Use `setup_paper_application_context` in tests

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
- Standardized authentication patterns using Current attributes
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

## Application Testing Patterns

**UPDATED - December 2025**: New patterns established during Application test consolidation

### Current Attributes in Tests

All tests requiring paper application context should use Current attributes:

```ruby
class ApplicationTest < ActiveSupport::TestCase
  setup do
    Current.paper_context = true
    Current.skip_proof_validation = true
  end

  teardown do
    Current.reset
  end
    @timestamp = Time.current.to_f.to_s.gsub('.', '')
  end

  teardown do
    Current.reset  # Clean up all Current attributes
  end
end
```

**Key Benefits**:
- Automatic cleanup between tests
- No state leakage between test runs
- Rails-native approach
- Consistent with request isolation

### Unique Test Data Pattern

To avoid validation conflicts, use timestamp-based unique identifiers:

```ruby
setup do
  @timestamp = Time.current.to_f.to_s.gsub('.', '')
end

def create_unique_user
  Users::Constituent.create!(
    email: "test#{@timestamp}@example.com",
    phone: "555#{@timestamp[-7..-1]}",
    first_name: 'Test',
    last_name: 'User'
  )
end

def create_unique_application_params
  {
    constituent: {
      email: "user#{@timestamp}@example.com",
      phone: "202555#{@timestamp[-4..-1]}",
      # ... other attributes
    },
    application: {
      # ... application attributes
    }
  }
end
```

### Mailer Expectations Pattern

Set up mailer expectations **before** calling the service:

```ruby
test 'service triggers email notification' do
  # Set up expectations FIRST
  mock_mailer = mock('ActionMailer::MessageDelivery')
  mock_mailer.expects(:deliver_later)
  
  ApplicationNotificationsMailer.expects(:account_created)
                                .with(anything, anything)
                                .returns(mock_mailer)
  
  # THEN call the service
  service = MyService.new(params: @params, admin: @admin)
  assert service.create
end
```

### EventDeduplicationService Testing

Test the deduplication service with proper time separation:

```ruby
test 'groups events by time window' do
  service = EventDeduplicationService.new
  time = Time.current.beginning_of_minute
  
  # Create events with specific timestamps
  event1 = create_event(created_at: time)
  event2 = create_event(created_at: time + 30.seconds)  # Same window
  event3 = create_event(created_at: time + 70.seconds)  # Different window
  
  result = service.deduplicate([event1, event2, event3])
  
  # First two should be deduplicated, third separate
  assert_equal 2, result.size
end
```

## Test Coverage Status

**Application-Related Tests - December 2025**:
- ✅ **76 tests passing** (100% success rate)
- ✅ **319 assertions** all successful  
- ✅ **0 failures, 0 errors**
- ✅ **3 intentionally skipped tests**

### Test Files Verified
- `Applications::EventDeduplicationServiceTest` - 2 tests
- `Applications::CertificationEventsServiceTest` - 2 tests
- `Applications::FilterServiceTest` - 13 tests
- `Applications::ApplicationCreatorTest` - 12 tests
- `Applications::AuditLogBuilderTest` - 9 tests
- `Applications::PaperApplicationAttachmentTest` - 2 tests
- `Applications::PaperApplicationServiceTest` - 5 tests
- `Applications::ReportingServiceTest` - 7 tests
- `Applications::MedicalCertificationReviewerTest` - 7 tests
- Additional service and model tests 