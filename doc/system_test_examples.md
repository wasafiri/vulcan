# System Test Examples

## Best Practices for Stable System Tests

This document provides practical examples of more stable system tests for our application.

### Example: Medical Certification Test

Here's an example of how we've improved our system tests for better stability:

```ruby
# BEFORE: One large complex test with multiple interactions
test "admin can send and track medical certification requests" do
  sign_in(@admin)
  visit admin_application_path(@application)
  
  click_button "Send Request" 
  assert_text "Certification request sent successfully"
  
  within(".certification-history") do
    assert_text "Request 1 sent on"
  end
  
  click_button "Resend Request"
  
  within(".certification-history") do
    assert_text "Request 1 sent on"
    assert_text "Request 2 sent on"
  end
  
  assert_selector ".certification-status", text: "Requested"
  assert_text @application.medical_provider_name
end

# AFTER: Multiple focused tests with better error handling
# Test 1: Simple viewing test
test "admin can view medical certification section" do
  safe_browser_action do
    sign_in(@admin)
    visit admin_application_path(@application)
    wait_for_complete_page_load
    
    assert_text "Medical Certification Status"
    assert_text @application.medical_provider_name
  end
end

# Test 2: Focused on a single interaction
test "admin can send medical certification request" do
  safe_browser_action do
    sign_in(@admin)
    visit admin_application_path(@application)
    
    safe_accept_alert do
      click_button "Send Request"
    end
    wait_for_complete_page_load
    
    assert_text "Certification request sent successfully"
    assert_selector ".certification-history", count: 1
  end
end
```

## Key Improvements

1. **Smaller, Focused Tests**
   - Each test does one thing, making failures easier to diagnose
   - Tests run faster and are less prone to timeout issues

2. **Error Handling Wrappers**
   - `safe_browser_action` adds retry logic for common browser errors
   - `safe_accept_alert` handles confirmation dialogs reliably

3. **Explicit Waiting**
   - `wait_for_complete_page_load` ensures the page is fully loaded
   - Provides consistent timing for dynamic content

4. **Better Setup/Teardown**
   - More robust browser cleanup after tests
   - Prevents orphaned processes and sessions

5. **DB Setup Instead of UI Interactions**
   - Use direct database manipulation for setup when possible
   - Reduces reliance on browser interactions for test preconditions

## Running Single Tests

To run a focused test for debugging:

```bash
bundle exec rails test test/system/medical_certification_test.rb -n "test_admin_can_view_medical_certification_section"
```

## Common Issues and Solutions

1. **Timeouts with Complex Tests**
   - Solution: Break into smaller, more focused tests
   - Solution: Add logging to identify slow operations

2. **Alert/Confirmation Dialog Issues**
   - Solution: Use `safe_accept_alert` helper
   - Solution: Disable alerts via JS for certain tests

3. **Browser Process Issues**
   - Solution: Force kill Chrome processes before/after tests
   - Solution: Use a more robust driver configuration

4. **Session Management Problems**
   - Solution: Reset Capybara sessions properly
   - Solution: Use `quit` instead of just closing windows
