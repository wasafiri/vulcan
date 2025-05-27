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
- Uses `Applications::PaperApplicationService` with proper thread-local context
- Handles both existing and new guardian scenarios

## Thread-Local Context

Uses `Thread.current[:paper_application_context]` to bypass certain validations during admin paper application processing:
- `ProofConsistencyValidation#skip_proof_validation?` 
- `ProofManageable#require_proof_validations?`

Always wrap paper application logic:
```ruby
Thread.current[:paper_application_context] = true
begin
  # Paper application logic
ensure
  Thread.current[:paper_application_context] = nil
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
- Set thread-local context for paper application tests
- Verify both `user_id` (applicant) and `managing_guardian_id` are correct

## Migration Notes

The system migrated from deprecated fields:
- ~~`users.is_guardian`~~ (removed)
- ~~`users.guardian_relationship`~~ (removed)  
- ~~`users.guardian_id`~~ (removed)

All functionality now uses the explicit GuardianRelationship model and Application.managing_guardian_id. 