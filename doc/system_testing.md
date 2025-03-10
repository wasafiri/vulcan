# System Testing Guidelines

This document outlines best practices for writing and maintaining system tests in our application.

## Common Challenges with System Tests

System tests often encounter issues due to:

1. **Browser session management** - Browsers can behave unpredictably in headless test environments
2. **Timing issues** - Tests might execute too quickly before the UI has updated
3. **JavaScript interactions** - Modern frameworks like Turbo Drive require special handling
4. **Alert and confirmation dialogs** - These require specific handling techniques
5. **Cleanup after tests** - Orphaned sessions can interfere with subsequent tests

## Helper Methods

To address these challenges, we've implemented several helper methods:

### Browser Action Helpers

```ruby
# Execute browser actions with retry logic
safe_browser_action do
  # Your test code here
end

# Handle confirmation dialogs safely
safe_accept_alert do
  click_button "Delete"
end

# Wait for both Turbo and animations
wait_for_complete_page_load
```

## Best Practices

1. **Wrap Test Cases in safe_browser_action**
   ```ruby
   test "user can view dashboard" do
     safe_browser_action do
       # Test code
     end
   end
   ```

2. **Handle Confirmation Dialogs Properly**
   ```ruby
   safe_accept_alert do
     click_button "Delete"
   end
   ```

3. **Wait for Page Load Completely**
   ```ruby
   visit some_path
   wait_for_complete_page_load
   ```

4. **Properly Clean Up Resources**
   - Let the framework handle browser session cleanup
   - Clear enqueued jobs after tests
   - Reset other global state that might affect other tests

## Example Test Structure

```ruby
test "admin can complete workflow" do
  safe_browser_action do
    # 1. Setup
    sign_in(@admin)
    
    # 2. Navigate
    visit admin_dashboard_path
    wait_for_complete_page_load
    
    # 3. Interact (with proper waiting)
    safe_accept_alert do
      click_button "Perform Action"
    end
    wait_for_complete_page_load
    
    # 4. Verify
    assert_text "Action completed successfully"
    within(".results") do
      assert_selector ".item", count: 3
    end
  end
end
```

## Troubleshooting

If you encounter issues with system tests:

1. **Browser Connection Issues**
   - Check for alerts that might be preventing browser actions
   - Ensure proper setup/teardown in the test

2. **Timing Issues**
   - Use appropriate wait methods
   - Add explicit waits for complex UI interactions

3. **Session Management**
   - Let the framework handle session cleanup
   - Don't manually manage the browser window

4. **JavaScript Errors**
   - Check browser console logs
   - Ensure JS dependencies are loaded

By following these guidelines, system tests should be more reliable and maintainable.
