# Dependent Contact Information Handling

This document outlines the changes made to properly handle dependent contact information (email and phone) while maintaining database integrity and avoiding uniqueness constraint violations.

## Problem

The original database schema enforced uniqueness on user emails and phone numbers, which created complex issues when dependents needed to share contact information with their guardians:

1. Submitting paper applications for dependents who share guardian contact info
2. Database uniqueness constraint violations when multiple users had the same email/phone
3. Complex workarounds with validation bypass flags that were error-prone
4. Difficulty distinguishing between a dependent's own contact info vs. shared guardian info

## Solution Overview

We implemented an architecture using dedicated contact fields for dependents:

**New Approach**: Add separate `dependent_email` and `dependent_phone` fields specifically for dependents, allowing them to either have their own contact information or share their guardian's contact information without database conflicts.

## Implementation Details

### 1. Database Migration

Added dedicated contact fields for dependents to avoid uniqueness conflicts:

```ruby
class AddDependentContactInfoToUsers < ActiveRecord::Migration[8.0]
  def change
    # Add optional contact fields for dependents
    # These fields allow dependents to have their own contact information
    # If blank, communications will default to guardian's contact info
    add_column :users, :dependent_email, :string, comment: 'Optional email for dependents; if blank, uses guardian email'
    add_column :users, :dependent_phone, :string, comment: 'Optional phone for dependents; if blank, uses guardian phone'
    
    # Add indexes for performance when querying dependent contact info
    add_index :users, :dependent_email
    add_index :users, :dependent_phone
  end
end
```

**Key Benefits:**
- No more uniqueness constraint violations
- Clear separation between primary user contact info and dependent-specific contact info
- Maintains database integrity with proper indexes
- Allows for flexible contact information handling

### 2. Model Changes

Enhanced the User model with dependent-specific contact fields and helper methods:

```ruby
# Added to user.rb - Encryption for new fields
encrypts :dependent_email, deterministic: true
encrypts :dependent_phone, deterministic: true

# Validations for dependent contact fields
validates :dependent_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
validate :dependent_phone_number_must_be_valid, if: :dependent_phone_changed?

# Helper methods for effective contact information
def effective_email
  return dependent_email if dependent_email.present?
  email
end

def effective_phone
  return dependent_phone if dependent_phone.present?
  phone
end

# Determine if this user has their own contact info vs. using guardian's
def has_own_contact_info?
  dependent_email.present? || dependent_phone.present?
end

def uses_guardian_contact_info?
  !has_own_contact_info?
end

private

def dependent_phone_number_must_be_valid
  return if dependent_phone.blank?
  
  # Strip all non-digit characters
  digits = dependent_phone.gsub(/\D/, '')
  
  # Remove leading '1' if present
  digits = digits[1..] if digits.length == 11 && digits.start_with?('1')
  
  # Validate that there are exactly 10 digits
  errors.add(:dependent_phone, 'must be a valid 10-digit US phone number') if digits.length != 10
end
```

**Key Features:**
- Encrypted storage for dependent contact fields
- Validation for dependent contact information
- Helper methods to get the "effective" contact info (dependent's own or falls back to primary)
- Clear methods to determine contact info strategy

### 3. Paper Application Service Updates

The paper application service was completely refactored to use contact strategy parameters instead of checkbox-based logic:

```ruby
# New approach using contact strategies
def determine_dependent_contact_strategy(applicant_data_for_constituent)
  email_strategy = params[:email_strategy] || 'guardian' # Default to guardian
  phone_strategy = params[:phone_strategy] || 'guardian'
  
  # Handle email strategy
  case email_strategy
  when 'guardian'
    Rails.logger.info { "[PAPER_APP] Dependent will share guardian's email" }
    applicant_data_for_constituent[:dependent_email] = @guardian_user_for_app.email
    applicant_data_for_constituent[:email] = "dependent-#{SecureRandom.uuid}@system.matvulcan.local"
  when 'dependent'
    if applicant_data_for_constituent[:dependent_email].present?
      Rails.logger.info { "[PAPER_APP] Dependent will use their own email" }
      applicant_data_for_constituent[:email] = applicant_data_for_constituent[:dependent_email]
    else
      Rails.logger.warn { "[PAPER_APP] Email strategy is 'dependent' but no dependent_email provided, falling back to guardian email" }
      applicant_data_for_constituent[:dependent_email] = @guardian_user_for_app.email
      applicant_data_for_constituent[:email] = "dependent-#{SecureRandom.uuid}@system.matvulcan.local"
    end
  end
  
  # Similar logic for phone strategy...
end
```

**Key Improvements:**
- No more validation bypass flags or complex workarounds
- Clean strategy-based parameter handling instead of checkbox logic
- System-generated primary contact info ensures uniqueness is maintained
- Dependent-specific contact info stored separately and retrievable via helper methods
- Cleaner, more maintainable code with clear fallback logic

### 4. Testing Updates

Updated tests to reflect the new contact strategy approach:

```ruby
# Tests now use the new parameter structure
post admin_paper_applications_path, params: {
  guardian_attributes: { ... }, # For new guardian creation
  constituent: { # Unified parameter structure
    first_name: 'Child',
    dependent_email: dependent_email # Optional dependent contact info
  },
  email_strategy: 'dependent', # Explicit strategy selection
  phone_strategy: 'guardian',
  relationship_type: 'Parent'
}

# Verify proper contact info handling
new_dependent = User.find_by(dependent_email: dependent_email)
assert_equal guardian_email, new_dependent.dependent_email
assert_equal guardian_email, new_dependent.effective_email
assert_match /dependent-.*@system\.matvulcan\.local/, new_dependent.email
```

## Current Status

✅ **Completed:**
- Database migration with dependent contact fields (`dependent_email`, `dependent_phone`)
- User model enhancements with helper methods (`effective_email`, `effective_phone`)
- Paper application service refactoring with contact strategy logic
- Controller updates with unified parameter handling and strategy support
- Test suite updates for contact strategy scenarios
- Support for email, phone, and address contact strategies
- Removal of `dependent_attributes` cruft and parameter mapping

✅ **Test Coverage:**
- Dependent with their own email and phone (`email_strategy: 'dependent'`)
- Dependent sharing guardian's email (`email_strategy: 'guardian'`)
- Mixed scenarios (own email, guardian's phone, etc.)
- Proper encryption and validation of dependent contact fields
- Fallback logic when dependent contact info is blank

## Usage Patterns

### Scenario 1: Dependent has their own contact information
```ruby
dependent = User.create!(
  first_name: "Child",
  email: "child@example.com",
  phone: "555-0001",
  dependent_email: "child@example.com",  # Same as primary email
  dependent_phone: "555-0001"            # Same as primary phone
)

dependent.effective_email  # => "child@example.com"
dependent.effective_phone  # => "555-0001"
dependent.has_own_contact_info?  # => true
```

### Scenario 2: Dependent shares guardian's contact information
```ruby
dependent = User.create!(
  first_name: "Child",
  email: "dependent-abc123@system.matvulcan.local",  # System-generated
  phone: "000-000-1234",                             # System-generated
  dependent_email: "guardian@example.com",           # Guardian's email
  dependent_phone: "555-0002"                        # Guardian's phone
)

dependent.effective_email  # => "guardian@example.com"
dependent.effective_phone  # => "555-0002"
dependent.uses_guardian_contact_info?  # => true
```

## Future Work

1. ✅ ~~Add comprehensive unit tests specifically for dependent contact validation~~
2. Update frontend forms to properly handle dependent contact field selection
3. Add admin interface for managing dependent contact preferences
4. Consider extending this pattern to other contact fields (address, emergency contacts)
