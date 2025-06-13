# Service Architecture

Short, actionable reference for how our service objects work and how to build new ones.

---

## 1 · Philosophy

| Principle | In practice |
|-----------|-------------|
| **Encapsulate business logic** | One service ↔ one use-case. Keep controllers/models thin. |
| **Consistent patterns** | All services inherit helpers from `BaseService`. |
| **Transactional safety** | Wrap side-effect chains in DB transactions. |
| **Clear result surface** | Return `true/false`, expose `errors`. Complex services may return a result hash. |

---

## 2 · BaseService

```ruby
class BaseService
  attr_reader :errors

  def initialize
    @errors = []
  end

  protected

  def add_error(message)
    @errors << message
    false
  end

  def log_error(exception, context = nil)
    Rails.logger.error "#{self.class.name}: #{context} - #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n") if exception.backtrace
  end
end
```

---

## 3 · Core Services (examples)

### 3.1 · Applications::EventDeduplicationService

```ruby
deduped = Applications::EventDeduplicationService
           .new.deduplicate(events)
```

* **Single source of truth** for event deduping.  
* 1-minute buckets, priority: StatusChange > Event > Notification.  
* Fingerprints events via `event_fingerprint(event)`.

<details>
<summary>Fingerprint snippet</summary>

```ruby
def event_fingerprint(event)
  action  = generic_action(event)
  details = case event
            when ApplicationStatusChange
              medical_certification_event?(event) ? nil :
                "#{event.from_status}-#{event.to_status}"
            when ->(e) { e.action&.include?('proof_submitted') }
              "#{event.metadata['proof_type']}-#{event.metadata['submission_method']}"
            end
  [action, details].compact.join('_')
end
```
</details>

---

### 3.2 · Applications::MedicalCertificationService

```ruby
service = Applications::MedicalCertificationService
            .new(application: app, actor: current_user)
service.request_certification
```

* Uses `update_columns` to avoid unrelated validations.  
* Timestamps = audit trail.  
* Background jobs for emails; graceful error capture.

---

### 3.3 · Applications::PaperApplicationService

(See **Paper Application Architecture** doc for full details.)

Key points:

| Concern | How handled |
|---------|-------------|
| Validation bypass | `Current.paper_context = true` |
| Self vs dependent | GuardianRelationship creation when needed |
| Proofs | Accept / reject, uploads, audits |
| Notifications | Triggered after success |

---

### 3.4 · Applications::EventService

```ruby
service = Applications::EventService
            .new(application: app, user: current_user)
service.log_dependent_application_update(
  dependent: dep, relationship_type: 'Parent'
)
```

Centralises event + metadata logging.

---

### 3.5 · ProofAttachmentService

```ruby
result = ProofAttachmentService.attach_proof(
  application:        app,
  proof_type:         'income',
  blob_or_file:       uploaded_file,
  status:             :approved,
  admin:              current_user,
  submission_method:  :paper,
  metadata:           { ip: request.remote_ip }
)
```

* Supports files **or** signed blob IDs.  
* Auto-creates audits; honours `Current.paper_context`; returns structured result.

---

## 4 · Service Patterns & Helpers

### 4.1 · CurrentAttributes

```ruby
Current.paper_context         # bypass proof checks
Current.skip_proof_validation # broader bypass
Current.force_notifications   # useful in tests
```

* Rails-native cleanup between requests.  
* Test isolation with `Current.reset` in teardown.

### 4.2 · Standard Error Handling

```ruby
def perform_operation
  ActiveRecord::Base.transaction do
    return add_error('Validation failed') unless valid?

    perform_core_logic
    true
  end
rescue => e
  log_error(e, 'perform_operation')
  add_error(e.message)
end
```

### 4.3 · Result Object Template

```ruby
{ success: false, error: nil, duration_ms: 0 }
```

Populate and return from service when you need more than a boolean.

---

## 5 · Guardian / Dependent Logic (in services)

```ruby
if applicant_type == 'dependent'
  guardian   = find_or_create_guardian
  dependent  = create_dependent_with_guardian_info
  GuardianRelationship.create!(
    guardian_user:  guardian,
    dependent_user: dependent,
    relationship_type: relationship_type
  )
else
  dependent = find_or_create_self_applicant
end
```

---

## 6 · Testing Services

### 6.1 · Unit Test Skeleton

```ruby
class FooServiceTest < ActiveSupport::TestCase
  setup { @admin = create(:admin) }

  test 'success' do
    service = FooService.new(admin: @admin)
    assert service.perform
    assert_empty service.errors
  end

  test 'handles failure' do
    Foo.stubs(:create!).raises(StandardError, 'boom')
    service = FooService.new(admin: @admin)
    assert_not service.perform
    assert_includes service.errors, 'boom'
  end
end
```

### 6.2 · Integration Example

```ruby
assert_difference ['Application.count', 'GuardianRelationship.count'] do
  assert Applications::PaperApplicationService
           .new(params: dep_params, admin: @admin).create
end
```

---

## 7 · When to Extract a Service

* Logic spans **multiple models**.  
* Needs **transaction** wrapping.  
* Complex **error handling**.  
* **Background job** orchestration.  
* The controller/model would otherwise grow unwieldy.

---

## 8 · Future Service Candidates

| Area | Why |
|------|-----|
| Voucher management | Multi-step issuance, expiry, audit trail |
| Status transitions | State-machine-like rules, notifications |
| User verification | Document uploads, external checks |
| Notification orchestration | Multiple channels + rules |
| Report generation | Large data aggregation, formatting |

---

## 9 · Dos & Don’ts

| Do | Don’t |
|----|-------|
| Keep services PORO-ish | Render views |
| Return clear success/failure | Manage sessions |
| Log & collect errors | Parse complex params (use form objects) |
| Maintain audits | Skip transactions when needed |
| Use models/scopes for queries | Embed raw SQL everywhere |