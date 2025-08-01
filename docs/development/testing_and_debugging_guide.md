# Testing and Debugging Guide

## 1. Core Testing Concepts
### Test Suite Overview
- High rate of passing tests with extensive assertions
- Shared helper modules to reduce duplication
- Standardized authentication patterns
- Accurate FPL calculations
- Consolidated and standardized for reliability

### Quick Start
```bash
# Minimal output
rails test test/system/some_test.rb
./bin/test-quiet test/system/some_test.rb

# Full debugging
VERBOSE_TESTS=1 rails test test/system/some_test.rb
./bin/test-verbose test/system/some_test.rb

# Special cases
USE_TRUNCATION=1 rails test        # Force truncation
HEADLESS=false rails test          # Visual debugging
DEBUG_AUTH=true rails test         # Auth debug info
```

## 2. Configuration & Setup
### Environment Configuration
- **Log Level**: `:warn` (default), `:debug` (with VERBOSE_TESTS=1)
- **Database Strategy**: `transaction` (default), `truncation` (with USE_TRUNCATION=1)
- **Seeding**: Only shows errors unless verbose mode
- **Auto-loading**: Support files from `test/support/`

### Browser Configuration
- **Driver**: Cuprite with Chrome
- **Headless Mode**: Controlled by `HEADLESS` env var
- **Performance**: Animations disabled, optimized options
- **Debug**: `SLOWMO=0.5` for step debugging

### Log Noise Reduction
- Default log level: `:warn`
- Verbose mode: `VERBOSE_TESTS=1` sets `:debug`
- Database strategy optimized for speed
- Browser settings minimize unnecessary output

## 3. Authentication Patterns
### Test Type-Specific Methods
```ruby
# Unit/Controller tests
sign_in_for_controller_test(user)  # or sign_in_as(user)

# Integration tests
sign_in_for_integration_test(user) # or sign_in_with_headers(user)

# Unit tests
sign_in_for_unit_test(user)        # or update_current_user(user)

# System tests
system_test_sign_in(user)
with_authenticated_user(user) { ... }
```

### Authentication Core
- Uses `Thread.current[:test_user_id]` consistently
- Shared `AuthenticationCore` module
- Automatic session cleanup
- Explicit methods prevent context detection issues

## 4. Helper Utilities
### Shared Helpers
```ruby
# FPL policy setup (400% modifier)
setup_fpl_policies

# Paper application context
setup_paper_application_context
teardown_paper_application_context
```

### Attachment Handling
```ruby
# Mocked attachments
mock_attached_file(filename: 'doc.pdf', ...)
create(:application, :with_mocked_income_proof)

# Real attachments (integration tests)
create(:application, :with_real_income_proof)

# Waiting period handling
create(:application, :old_enough_for_new_application)
```

### System Test Helpers
```ruby
# Synchronization
wait_for_network_idle(timeout: 10)
wait_for_turbo(timeout: 5)

# Debugging
assert_notification(text, type: nil)
take_screenshot(name)
safe_browser_action
```

## 5. Common Issues & Solutions
### Authentication Issues
- Use appropriate sign-in helpers per test type
- Verify with `assert_authenticated_as(user)`
- Add `wait_for_turbo` after navigation
- Handle waiting period conflicts with `:old_enough_for_new_application`

### Element Not Found
- Use stable selectors (IDs, data attributes)
- `visible: :all` for conditionally hidden elements
- Explicit waits: `assert_selector 'selector', wait: 5`
- Safe helpers: `safe_click`, `safe_fill_in`

### JavaScript/Stimulus Issues
- Verify controller registration
- Check `data-controller` and `data-target`
- Add waits after JS actions
- `wait_for_stimulus_controller(controller_name)`

### Timing Issues
- Wait for Turbo navigation completion
- Ensure background jobs complete
- Avoid arbitrary sleeps
- Pattern for state transitions:
  ```ruby
  element = find('#element')
  element.click
  assert_no_selector('#element.old-state', wait: 5)
  assert_selector('#element.new-state', wait: 5)
  ```

### Database/Backend Errors
- Verify test data setup
- Use shared helpers: `setup_fpl_policies`
- Handle waiting period conflicts
- Check Current attributes context

## 6. Advanced Testing Topics
### 6.5 Capybara Advanced Waiting Strategies

Capybara provides sophisticated tools for avoiding race conditions in JavaScript-heavy applications:

**Count Expectations for Dynamic Content:**
```ruby
# Wait for exactly the expected number of elements
all '.notification', count: 2

# Wait for at least one element to appear
all '.search-result', minimum: 1

# Wait for at most one modal to be visible
all '.modal.visible', maximum: 1

# Wait for elements within a range
all '.item', between: 3..5
```

**Configurable Wait Times:**
```ruby
# Global wait time configuration (in test setup)
Capybara.default_max_wait_time = 5 # Seconds

# Per-operation wait time for slow operations
find('.slow-loading-content', wait: 15)
all '.ajax-content', count: 1, wait: 10
```

**Critical Understanding: DOM vs AJAX:**
Capybara doesn't wait for AJAX requests to complete - it waits for DOM elements to appear or change. This means you should wait for the visual result of AJAX, not the AJAX call itself.

**Element State Transition Pattern:**
For complex interactions where elements change state:

```ruby
# 1. Identify element that will change
submit_button = find('#submit-button')

# 2. Perform action that triggers change
submit_button.click

# 3. Wait for old state to disappear
assert_no_selector('#submit-button.enabled', wait: 5)

# 4. Wait for new state to appear  
assert_selector('#submit-button.disabled', wait: 5)
```

**Race Condition Prevention Pattern:**
The most common JavaScript timing issue:

1. **Trigger Action**: JavaScript starts asynchronous operation
2. **Premature Check**: Test immediately checks for result (fails)
3. **Late Completion**: JavaScript finishes after test has failed

**Solution:**
```ruby
# 1. Trigger the JavaScript action
click_button 'Submit Form'

# 2. Wait for intermediate state that proves JS is working
assert_selector('.processing-indicator', wait: 5)

# 3. Wait for completion indicator
assert_no_selector('.processing-indicator', wait: 10)

# 4. Now assert final result (JS has definitely completed)
assert_selector('.success-message', wait: 5)
```

**Selector Reliability Hierarchy:**
```ruby
# ❌ Worst: Generic selectors prone to conflicts
find('button').click

# ✅ Better: Type-specific selectors
find('button[type=submit]').click

# ✅ Best: Unique identifiers
find('#unique-submit-button').click
find('[data-testid="submit-btn"]').click
```

### 6.6 Cuprite-Specific Configuration Flags

Essential Chrome flags for stability:
```ruby
# Essential Chrome flags for test stability
browser_options: {
  'smooth-scrolling' => false,                    # Prevent scrolling timing issues
  'disable-background-animations' => nil,          # Reduce animation interference  
  'disable-renderer-backgrounding' => nil,        # Prevent background tab issues
  'disable-backgrounding-occluded-windows' => nil
}
```

### ActionMailbox Testing
```ruby
# Configuration
Rails.application.config.action_mailbox.ingress = :test

# Email processing
inbound_email = receive_inbound_email_from_mail(
  to: 'inbox@example.com',
  from: user.email,
  subject: 'Test',
  body: 'Content'
) do |mail|
  mail.attachments['file.pdf'] = 'PDF content'
end

# Verify outcomes
application.reload
assert application.income_proof.attached?
```

### Service Testing Patterns
**Return Value Handling:**
```ruby
# ServiceResult pattern
result = SomeService.new(...).call
if result.success?
  data = result.data
end

# Direct return
data = SomeService.new(...).call

# Best practices:
test 'service returns expected interface' do
  result = SomeService.new(...).call
  assert_respond_to result, :expected_method
end
```

### Event Deduplication
**Solutions:**
```ruby
# Remove duplicate callbacks
after_save :log_changes # instead of after_update + after_save

# Context guards
return if Current.paper_context?

# Centralize logging
AuditEventService.log(...)
NotificationService.create_and_deliver!(...)
```

### Cuprite & Docker Setup
```yaml
# docker-compose.yml
dev-chrome:
  image: browserless/chrome:latest
  ports: ["3333:3333"]
  environment:
    PORT: 3333
    CONNECTION_TIMEOUT: 600000
```

```ruby
# Capybara configuration
Capybara.register_driver(:better_cuprite) do |app|
  # Custom configuration
end
```

## 7. Architectural Patterns
### Policy System
- `Policy.get('key')` performs real database queries
- Create real records instead of stubbing:
  ```ruby
  Policy.find_or_create_by!(key: 'max_proof_rejections', value: 3)
  ```

### Proof Attachment
- Service-based architecture:
  ```ruby
  ProofAttachmentService.attach_proof({
    application: @application,
    proof_type: params[:proof_type],
    blob_or_file: params[:proof_upload]
  })
  ```
- Avoid stubbing core business logic

### Audit Logging
- Two-call pattern:
  ```ruby
  AuditEventService.log(action: "proof_submitted")
  NotificationService.create_and_deliver!(type: "proof_attached")
  ```

## 8. Best Practices & Workflows
### Test Structure
```ruby
class MySystemTest < ApplicationSystemTestCase
  def setup
    @user = create(:user)
  end

  def test_feature
    system_test_sign_in(@user)
    visit feature_path
    wait_for_turbo
    
    safe_fill_in('#input', with: 'value')
    safe_click('#submit')
    
    assert_text 'Success'
    assert_current_path success_path
  end
end
```

### Debugging Workflow
1. Run tests in isolation
2. Enable verbose mode (`VERBOSE_TESTS=1`)
3. Use visual browser (`HEADLESS=false`)
4. Add screenshots before assertions
5. Verify authentication state
6. Check browser dev tools for JS errors

### Anti-Patterns to Avoid
- Over-stubbing database queries
- Stubbing core business services
- Duplicate audit logging
- Mixing DirectUpload implementations
- Ignoring missing Policy records

### Environment Variables
| Variable | Purpose | Values |
|----------|---------|--------|
| `VERBOSE_TESTS` | Debug output | `1` (enable) |
| `USE_TRUNCATION` | DB strategy | `1` (force truncation) |
| `HEADLESS` | Browser visibility | `false` (visible) |
| `SLOWMO` | Debug delays | `1.0` (1 second delay) |
| `DEBUG_AUTH` | Auth debug | `true` (enable) |

## 9. Additional Solutions

When tests start failing intermittently, try these solutions in order:

### Element Finding Patterns

**❌ Unstable Patterns to Avoid:**
- `first('button', text: 'Review Proof').click` - prone to stale references
- `page.all('selector')[index].click` - position-dependent, unreliable
- `find('button').click` without waiting - races with DOM changes

**✅ Stable Patterns to Use:**
- `find(:element, "button", "data-modal-id": "incomeProofReviewModal").click` - attribute-based, stable
- `click_button 'Specific Text', match: :first` - Rails-style, waits properly
- `find('[data-testid="element-id"]').click` - if data-testid attributes are available
