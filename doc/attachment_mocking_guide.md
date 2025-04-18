# Standardized Attachment Mocking Guide

## Overview

This guide outlines our standardized approach to mocking ActiveStorage attachments in tests. 
Using a consistent approach helps prevent common errors like the dreaded "unexpected invocation: #<Mock:0x...>.byte_size()" 
that can occur when tests interact with ActiveStorage attachments.

## Recommended Approach

The preferred way to mock attachments is to use the `AttachmentTestHelper#mock_attached_file` method:

```ruby
# Example of mocking an attachment in a test
def test_something_with_attachments
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
  
  # ... rest of your test
end
```

## Benefits

This approach offers several advantages:

1. **Comprehensive mocking**: All essential attachment methods are stubbed with reasonable defaults
2. **Consistency**: All tests use the same mocking pattern, reducing confusion
3. **Maintainability**: If the ActiveStorage API changes, we only need to update one helper 
4. **Flexibility**: You can customize any attachment attribute when needed

## Legacy Approaches (Deprecated)

For backward compatibility, these older methods still work but are now deprecated:

- `MockAttachmentHelper#mock_attachment_with_all_methods` - Use `mock_attached_file` instead
- `MockAttachmentHelper#setup_attachment_mocks_for_audit_logs` - Consider more targeted mocking 
- `MockAttachmentHelper#setup_attachment_mocks_for_application` - Consider more explicit mocking

All these methods now delegate to the standardized `mock_attached_file` method internally.

## Real vs Mocked Attachments

In some tests, especially integration tests, you might need real attachments instead of mocks. 
For these cases:

```ruby
# Use ActiveStorageTestHelper for real (but simple) attachments
def test_with_real_attachments
  application.income_proof.attach(
    io: StringIO.new('income proof content'),
    filename: 'income.pdf',
    content_type: 'application/pdf'
  )
end
```

## Application Factory Traits

We've created standardized traits in our application factory for both mocked and real attachments:

### Mocked Attachment Traits

```ruby
# Create an application with mocked attachments
application = create(:application, :with_mocked_income_proof)

# Or use with_all_mocked_attachments for full attachment mocking
application = create(:application, :with_all_mocked_attachments)
```

Available mock traits:
- `:with_mocked_income_proof` - Adds a mocked income proof attachment
- `:with_mocked_residency_proof` - Adds a mocked residency proof attachment  
- `:with_mocked_medical_certification` - Adds a mocked medical certification attachment
- `:with_all_mocked_attachments` - Adds all three mocked attachments

These traits automatically handle all the stubbing using the standardized `mock_attached_file` approach.

### Real Attachment Traits

```ruby
# Create an application with real attachments
application = create(:application, :with_real_income_proof)

# Or use with_all_real_attachments for full attachment setup
application = create(:application, :with_all_real_attachments)
```

Available real attachment traits:
- `:with_real_income_proof` - Adds a real income proof attachment
- `:with_real_residency_proof` - Adds a real residency proof attachment  
- `:with_real_medical_certification` - Adds a real medical certification attachment
- `:with_all_real_attachments` - Adds all three real attachments

These traits use `ActiveStorageTestHelper` to attach actual StringIO objects.

## When to Use Each Approach

### Use Mocked Attachments For:

- Unit tests where you only care about an attachment's presence/absence
- Performance-sensitive tests (mocks are much faster)
- Controller tests where you don't need to verify file processing
- Tests where you don't care about actual file content

```ruby
# Example: Testing an application status change that doesn't process the attachment
test "approving an application updates its status" do
  app = create(:application, :with_mocked_income_proof, :with_mocked_residency_proof)
  
  app.approve!
  
  assert_equal "approved", app.status
end
```

### Use Real Attachments For:

- Integration and system tests that test file processing
- Tests of attachment-specific functionality
- When testing features that interact with file content
- When testing ActiveStorage-specific behavior

```ruby
# Example: Testing actual file content processing
test "income proof content is analyzed" do
  app = create(:application, :with_real_income_proof)
  
  IncomeAnalysisService.analyze(app)
  
  assert app.income_verified?
end
```

## Best Practices

1. **Use factory traits whenever possible**: The traits in `applications.rb` handle all the attachment details for you
2. **Be explicit about mocking**: Always clearly indicate when you're using a mock vs. real attachment
3. **Use mock_attached_file for unit tests**: It's faster and doesn't rely on actual files
4. **Use real attachments for integration tests**: When testing the full stack behavior
5. **Avoid thread-local state hacks**: The old approach of using thread-local state to bypass validations is discouraged
6. **Consider factories for model setup**: Use FactoryBot with the appropriate traits rather than bypassing validations
7. **Prefer module methods over instantiation**: Most helper methods can be called directly without instantiating the helper

## Migration Path from Legacy Approaches

If you find tests using any of these legacy patterns, here's how to update them:

```ruby
# OLD APPROACH - avoid this
Thread.current[:skip_proof_validation] = true
application.income_proof.attach(...)
Thread.current[:skip_proof_validation] = false

# NEW APPROACH - use this instead
create(:application, :with_real_income_proof)
```

```ruby
# OLD APPROACH - avoid this
application.stubs(:income_proof).returns(some_mock)
application.stubs(:income_proof_attached?).returns(true)

# NEW APPROACH - use this instead 
create(:application, :with_mocked_income_proof)
```

```ruby
# OLD APPROACH - avoid this
setup_attachment_mocks_for_application(application)

# NEW APPROACH - use this instead
create(:application, :with_all_mocked_attachments)
```

## Troubleshooting

If you encounter errors like:

```
unexpected invocation: #<Mock:0x...>.byte_size()
```

It usually means you haven't properly mocked all the methods that are being called on your attachment. 
Switch to using `mock_attached_file` which covers all the common methods.
