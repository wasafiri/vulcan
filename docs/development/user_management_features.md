# User Management Features

## User Signup Deduplication

### Strategy Overview
A two-pronged approach prevents duplicate user accounts during registration:

1. **Strict Uniqueness on Phone Number**
2. **Soft Check for Name + Date of Birth Duplicates**

### Phone Number Uniqueness
- **Database Constraint**: Unique index on `users.phone` column
- **Model Validation**: `validates :phone, uniqueness: true`
- **Normalization**: Phone numbers normalized before validation
  - Stripped of non-digits
  - Leading '1' removed
  - Formatted to XXX-XXX-XXXX

```ruby
# In User model
before_validation :format_phone_number

def format_phone_number
  return if phone.blank?
  
  # Remove all non-digits
  cleaned = phone.gsub(/\D/, '')
  
  # Remove leading 1 if present
  cleaned = cleaned.sub(/^1/, '') if cleaned.length == 11
  
  # Format as XXX-XXX-XXXX
  if cleaned.length == 10
    self.phone = "#{cleaned[0..2]}-#{cleaned[3..5]}-#{cleaned[6..9]}"
  end
end
```

### Name + DOB Soft Check
Users with matching first name, last name (case-insensitive), and date of birth are flagged for administrative review:

- **Flag Field**: `needs_duplicate_review` boolean column (defaults to false)
- **Check Logic**: Performed in `RegistrationsController#create` before saving
- **User Experience**: Registration proceeds normally, flag is invisible to user

```ruby
# In RegistrationsController
def create
  @user = User.new(registration_params)
  
  # Check for potential duplicates before saving
  if potential_duplicate_found?(@user)
    @user.needs_duplicate_review = true
  end
  
  if @user.save
    # Normal registration flow
  else
    # Handle validation errors
  end
end

private

def potential_duplicate_found?(user)
  return false unless user.first_name.present? && user.last_name.present? && user.date_of_birth.present?

  User.exists?(['LOWER(first_name) = ? AND LOWER(last_name) = ? AND date_of_birth = ?',
                user.first_name.downcase,
                user.last_name.downcase,
                user.date_of_birth])
end
```

### User Experience

**Duplicate Email/Phone**: User receives standard validation error and cannot complete registration.

**Duplicate Name+DOB**: User's registration completes successfully with no indication of the duplicate flag.

### Admin Interface
The admin user index shows flagged users for review:

```erb
<% if user.needs_duplicate_review? %>
  <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
    Needs Review
  </span>
<% end %>
```

## Test Selectors and Stability

### Data Test ID Strategy
Use `data-testid` attributes for stable test selectors that won't change for styling or content reasons:

```erb
<form data-testid="sign-in-form">
  <input type="email" data-testid="email-input">
  <input type="password" data-testid="password-input">
  <button type="submit" data-testid="sign-in-button">Sign In</button>
</form>
```

### Naming Convention
Use hierarchical structure: `feature-component-element`

| Element Type | Pattern | Example |
|--------------|---------|---------|
| Forms | `{feature}-form` | `sign-in-form` |
| Inputs | `{name}-input` | `email-input` |
| Buttons | `{action}-button` | `submit-button` |
| Modals/Dialogs | `{feature}-modal` | `confirmation-modal` |
| Lists | `{item-type}-list` | `users-list` |
| List Items | `{item-type}-item` | `user-item` |

### Test Usage
```ruby
# Robust test selectors
within '[data-testid="sign-in-form"]' do
  fill_in '[data-testid="email-input"]', with: 'user@example.com'  
  fill_in '[data-testid="password-input"]', with: 'password'
  click_button '[data-testid="sign-in-button"]'
end
```

### Priority Areas for Implementation
1. **Authentication Forms** - Sign-in, sign-up, password reset
2. **Navigation Elements** - Key navigation components
3. **User Profile Components** - Profile edit forms
4. **Application Forms** - Application creation/editing
5. **Admin Panels** - Admin interface components

## User Factory Patterns

### Basic User Creation
```ruby
# Standard user
user = create(:user)

# User with specific traits
user = create(:user, :with_disabilities)
user = create(:constituent, :verified)
```

### Guardian/Dependent Relationships
```ruby
# User with dependents
guardian = create(:user, :with_dependent)
guardian = create(:user, :with_dependents) # Multiple dependents

# User with guardian
dependent = create(:user, :with_guardian)

# Explicit relationship creation
guardian = create(:user)
dependent = create(:user)
create(:guardian_relationship, guardian_user: guardian, dependent_user: dependent, relationship_type: 'Parent')
```

### Avoiding Uniqueness Conflicts
```ruby
# Generate unique values
user = create(:user, 
  email: generate(:email),
  phone: generate(:phone)
)

# Use timestamp-based uniqueness
timestamp = Time.current.to_i
user = create(:user,
  email: "user.#{timestamp}@example.com",
  phone: "555-#{timestamp.to_s[-4..]}"
)
```

## User Model Testing Patterns

### Testing Private Methods
```ruby
test 'private method behavior' do
  user = create(:user)
  result = user.send(:private_method_name, arguments)
  assert_equal expected_result, result
end
```

### Testing Validations
```ruby
test 'phone uniqueness validation' do
  existing_user = create(:user, phone: '555-1234')
  duplicate_user = build(:user, phone: '555-1234')
  
  assert_not duplicate_user.valid?
  assert_includes duplicate_user.errors[:phone], 'has already been taken'
end
```

### Testing Callbacks
```ruby
test 'phone formatting callback' do
  user = create(:user, phone: '(555) 123-4567')
  assert_equal '555-123-4567', user.phone
end
```

## Future Considerations

### Duplicate Review Process
- Develop admin interface for reviewing flagged users
- Implement account merging functionality
- Add resolution tracking for duplicate flags
- Consider automated duplicate detection improvements

### Enhanced Deduplication
- Add similar soft checks for address information
- Implement fuzzy matching for name variations
- Consider machine learning approaches for duplicate detection
- Add bulk duplicate detection for existing data

### Test Selector Expansion
- Add `data-testid` to all interactive elements
- Implement automated test selector validation
- Create style guide for consistent naming
- Consider tooling to strip test attributes from production builds 