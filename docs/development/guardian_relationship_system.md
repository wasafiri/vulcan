# Guardian Relationship System

Explicit `GuardianRelationship` records replace the old boolean flags, allowing each guardian to manage many dependents and vice-versa while preserving data integrity.

---

## 1 · Data Model

| Table | Key Columns | Notes |
|-------|-------------|-------|
| **guardian_relationships** | `guardian_id`, `dependent_id`, `relationship_type` | Unique index on `[guardian_id, dependent_id]`. |
| **applications** | `user_id`, `managing_guardian_id` | `user_id` = applicant; `managing_guardian_id` set only for dependents. |
| **users** (associations) | see below | |

```ruby
# user.rb
has_many :guardian_relationships_as_guardian,  foreign_key: :guardian_id
has_many :dependents, through: :guardian_relationships_as_guardian

has_many :guardian_relationships_as_dependent, foreign_key: :dependent_id
has_many :guardians, through: :guardian_relationships_as_dependent

has_many :managed_applications, foreign_key: :managing_guardian_id
```

---

## 2 · Dependent Contact Strategy

| Field | Purpose |
|-------|---------|
| `dependent_email` | Encrypted, optional e-mail for dependent |
| `dependent_phone` | Encrypted, optional phone |

**Own contact info**

```ruby
dependent = User.create!(
  email:            'child@example.com',
  phone:            '555-0001',
  dependent_email:  'child@example.com',
  dependent_phone:  '555-0001'
)
```

**Shared contact info**

```ruby
dependent = User.create!(
  email:            'dependent-abc123@system.local', # system-generated unique
  phone:            '000-000-1234',
  dependent_email:  'guardian@example.com',
  dependent_phone:  '555-0002'
)
```

Helper methods:

```ruby
dependent.effective_email  # prefers dependent_email
dependent.effective_phone  # prefers dependent_phone
dependent.has_own_contact_info?
dependent.uses_guardian_contact_info?
```

*Avoids uniqueness violations and supports real-world family setups.*

---

## 3 · Key Methods & Scopes

| Model | Method | Purpose |
|-------|--------|---------|
| **User** | `guardian?`, `dependent?` | Quick role checks |
|  | `dependent_applications` | All apps for dependents |
|  | `relationship_types_for_dependent(user)` | Returns relationship strings |
| **Application** | `for_dependent?` | bool |
|  | `guardian_relationship_type` | Returns relationship_type from link |
|  | `ensure_managing_guardian_set` | Callback for safety |

```ruby
# application scopes
scope :managed_by,            ->(g) { where(managing_guardian_id: g.id) }
scope :for_dependents_of,     ->(g) { joins(:guardian_relationships_as_guardian).where(guardian_relationships: { guardian_id: g.id }) }
scope :related_to_guardian,   ->(g) { managed_by(g).or(for_dependents_of(g)) }
```

---

## 4 · User Flows

### 4.1 · Web-Created Dependent

1. Guardian uses **“Add New Dependent”**.  
2. `GuardianRelationship` row created.  
3. Application: `user_id = dependent`, `managing_guardian_id = guardian`.  
4. Callback `ensure_managing_guardian_set` handles edge cases.

### 4.2 · Admin Paper Application

Handled by `Applications::PaperApplicationService`:

```ruby
Current.paper_context = true
begin
  # Service builds users, link, application
ensure
  Current.reset
end
```

Supports both new & existing guardians.

---

## 5 · Database Constraints

* Unique composite index on `(guardian_id, dependent_id)`.  
* FK constraints on both IDs.  
* `managing_guardian_id` nullable.

---

## 6 · Testing Patterns

```ruby
create(:user, :with_dependents)       # Guardian with many dependents
create(:application, :for_dependent)  # Factory sets managing_guardian_id
```

*Always*:

1. Build `GuardianRelationship` before dependent apps.  
2. Set `Current.paper_context` in paper-flow tests.  
3. Assert both `user_id` and `managing_guardian_id`.

Example:

```ruby
test 'dependent app sets guardian' do
  service = PaperApplicationService.new(params:, admin: @admin)
  assert_difference ['GuardianRelationship.count', 'Application.count'] do
    assert service.create
  end
  app = service.application
  assert app.for_dependent?
  assert_equal service.guardian_user_for_app.id, app.managing_guardian_id
end
```