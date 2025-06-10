# Guardian Relationship System

## Overview

The application uses an explicit `GuardianRelationship` model to manage relationships between guardian users and their dependents. This replaced the previous boolean-based system and enables robust tracking of multiple dependents per guardian.

## Data Model

### Core Models

**GuardianRelationship**
- `guardian_id` (foreign key to users.id) - The guardian user
- `dependent_id` (foreign key to users.id) - The dependent user  
- `relationship_type` (string) - e.g., "Parent", "Legal Guardian"
- Unique constraint on `[guardian_id, dependent_id]`

**Application**
- `user_id` - Always the actual applicant (the dependent if it's a minor's application)
- `managing_guardian_id` - Set when application is for a dependent, points to guardian

**User Associations**
```ruby
# Guardian relationships
has_many :guardian_relationships_as_guardian, foreign_key: 'guardian_id'
has_many :dependents, through: :guardian_relationships_as_guardian, source: :dependent_user

has_many :guardian_relationships_as_dependent, foreign_key: 'dependent_id'  
has_many :guardians, through: :guardian_relationships_as_dependent, source: :guardian_user

# Application management
has_many :managed_applications, foreign_key: 'managing_guardian_id'
```

## Dependent Contact Information

The system includes dedicated fields for dependent contact information to avoid database uniqueness constraint conflicts:

### Database Fields
- `dependent_email` (encrypted) - Optional email specific to dependent
- `dependent_phone` (encrypted) - Optional phone specific to dependent

### Contact Information Strategy

**Option 1: Dependent has own contact info**
```ruby
dependent = User.create!(
  email: "child@example.com",        # Dependent's own email
  phone: "555-0001",                 # Dependent's own phone
  dependent_email: "child@example.com",  # Same as primary
  dependent_phone: "555-0001"           # Same as primary
)
```

**Option 2: Dependent shares guardian's contact info**
```ruby
dependent = User.create!(
  email: "dependent-abc123@system.matvulcan.local",  # System-generated unique email
  phone: "000-000-1234",                             # System-generated unique phone
  dependent_email: "guardian@example.com",           # Guardian's actual email
  dependent_phone: "555-0002"                        # Guardian's actual phone
)
```

### Helper Methods
```ruby
# Get the effective contact information for communications
dependent.effective_email  # Returns dependent_email if present, otherwise email
dependent.effective_phone  # Returns dependent_phone if present, otherwise phone

# Determine contact strategy
dependent.has_own_contact_info?      # True if dependent has own email/phone
dependent.uses_guardian_contact_info?  # True if dependent shares guardian's contact
```

This approach ensures:
- No database uniqueness violations when dependents share guardian contact info
- Clean separation between system-required unique identifiers and communication preferences
- Flexibility for real-world family contact scenarios

## Key Methods

### User Model
- `is_guardian?` - Checks if user has any dependents
- `is_dependent?` - Checks if user has any guardians
- `dependent_applications` - Applications for user's dependents
- `relationship_types_for_dependent(user)` - Get relationship types with specific dependent

### Application Model
- `for_dependent?` - Returns true if `managing_guardian_id` is present
- `guardian_relationship_type` - Looks up relationship type from GuardianRelationship table
- `ensure_managing_guardian_set` - Callback to set managing_guardian_id when needed

### Scopes
```ruby
# Application scopes
scope :managed_by, ->(guardian_user) { where(managing_guardian_id: guardian_user.id) }
scope :for_dependents_of, ->(guardian_user) { joins guardian_relationships, filters by guardian }
scope :related_to_guardian, ->(guardian_user) { managed_by OR for_dependents_of }
```

## User Flows

### Creating Dependent Applications
1. Guardian creates dependent user via "Add New Dependent" 
2. GuardianRelationship record created linking guardian and dependent
3. When creating application, set `user_id` to dependent, `managing_guardian_id` to guardian
4. `ensure_managing_guardian_set` callback handles edge cases

### Paper Applications
- Admin can create guardian/dependent relationships during paper application process
- Uses `Applications::PaperApplicationService` with proper Current attributes context
- Handles both existing and new guardian scenarios

## Current Attributes Context

Uses `Current.paper_context` to bypass certain validations during admin paper application processing:
- `ProofConsistencyValidation#skip_proof_validation?` 
- `ProofManageable#require_proof_validations?`

Always wrap paper application logic:
```ruby
Current.paper_context = true
begin
  # Paper application logic
ensure
  Current.reset
end
```

## Database Constraints

- Unique index on `guardian_relationships(guardian_id, dependent_id)`
- Foreign key constraints to users table
- `managing_guardian_id` nullable (only set for dependent applications)

## Testing Considerations

### Factory Traits
```ruby
# User factories
create(:user, :with_dependent)     # Creates user with one dependent
create(:user, :with_dependents)    # Creates user with multiple dependents  
create(:user, :with_guardian)      # Creates user with a guardian

# Application factories
create(:application, :for_dependent)  # Creates application with managing_guardian_id set
```

### Common Test Patterns
- Always create GuardianRelationship before dependent applications
- Use proper factory traits to avoid manual relationship setup
- Set Current attributes context for paper application tests
- Verify both `user_id` (applicant) and `managing_guardian_id` are correct

## Migration Notes

The system migrated from deprecated fields:
- ~~`users.is_guardian`~~ (removed)
- ~~`users.guardian_relationship`~~ (removed)  
- ~~`users.guardian_id`~~ (removed)

All functionality now uses the explicit GuardianRelationship model and Application.managing_guardian_id. 