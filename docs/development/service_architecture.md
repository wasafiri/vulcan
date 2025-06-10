# Service Architecture

## Overview

The application uses service objects to encapsulate business logic and provide a maintainable, testable codebase. Services follow consistent patterns and handle complex operations that span multiple models.

## BaseService

The `BaseService` class provides common functionality for all service objects:

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

## Core Services

### Applications::EventDeduplicationService

**NEW - Consolidated December 2025**

Provides centralized, robust event deduplication across the entire application. This service replaced multiple competing deduplication systems that previously caused conflicts.

```ruby
service = Applications::EventDeduplicationService.new
deduplicated_events = service.deduplicate([notification, event, status_change])
```

**Key Features**:
- **Single Source of Truth**: Eliminates conflicts between multiple deduplication systems
- **Flexible Fingerprinting**: Handles Notification, Event, and ApplicationStatusChange objects
- **Time-Window Grouping**: 1-minute deduplication windows using proper bucketing
- **Priority-Based Selection**: ApplicationStatusChange > Event > Notification
- **Medical Certification Aware**: Special handling for medical certification events

**Fingerprinting Algorithm**:
```ruby
def event_fingerprint(event)
  action = generic_action(event)
  details = case event
            when ApplicationStatusChange
              if medical_certification_event?(event)
                nil # Group medical cert events together
              else
                "#{event.from_status}-#{event.to_status}"
              end
            when ->(e) { e.action&.include?('proof_submitted') }
              "#{event.metadata['proof_type']}-#{event.metadata['submission_method']}"
            else
              nil
            end
  [action, details].compact.join('_')
end
```

**Time Bucketing**:
```ruby
# Groups events into 1-minute windows
time_bucket = (event.created_at.to_i / DEDUPLICATION_WINDOW) * DEDUPLICATION_WINDOW
```

**Priority Selection**:
- ApplicationStatusChange: Priority 3 (highest)
- Event: Priority 2 (medium)  
- Notification: Priority 1 (lowest)

### Applications::MedicalCertificationService

Handles medical certification requests safely, avoiding validation conflicts:

```ruby
service = Applications::MedicalCertificationService.new(
  application: application,
  actor: current_user
)

if service.request_certification
  # Success path
else
  # Error handling with service.errors
end
```

**Key Features**:
- Uses `update_columns` to bypass unrelated model validations
- Maintains proper audit trails via timestamps
- Handles notification creation failures gracefully
- Uses background jobs for email delivery
- Logs detailed errors for troubleshooting

### Applications::PaperApplicationService

Handles paper application submissions by administrators with proper Current attributes context:

```ruby
service = Applications::PaperApplicationService.new(
  params: paper_application_params,
  admin: current_user
)

if service.create
  redirect_to admin_application_path(service.application)
else
  handle_errors(service.errors)
end
```

**Key Features**:
- Sets `Current.paper_context` to bypass online validations
- Handles both self-applicant and guardian/dependent scenarios
- Processes proof uploads and rejections
- Creates proper audit trails and notifications
- Manages GuardianRelationship creation for new dependents

### Applications::EventService

Centralizes event logging for applications with proper metadata:

```ruby
service = Applications::EventService.new(application: app, user: current_user)

# Log dependent application updates
service.log_dependent_application_update(
  dependent: dependent_user,
  relationship_type: 'Parent'
)

# Log submission events
service.log_submission_for_dependent(
  dependent: dependent_user,
  relationship_type: 'Parent'
)
```

### ProofAttachmentService

Handles proof file attachments with comprehensive error handling:

```ruby
result = ProofAttachmentService.attach_proof(
  application: application,
  proof_type: 'income',
  blob_or_file: uploaded_file,
  status: :approved,
  admin: admin_user,
  submission_method: :paper,
  metadata: { ip_address: request.remote_ip }
)

if result[:success]
  # Handle success
else
  # Handle error: result[:error]
end
```

**Features**:
- Supports both file uploads and signed blob IDs
- Creates audit records automatically
- Handles paper application context properly
- Provides detailed error reporting
- Records metrics for monitoring

## Service Patterns

### Current Attributes Context Management

**UPDATED - December 2025**: Migrated from Thread-local variables to Rails CurrentAttributes

Services that need to bypass validations use Current attributes for better isolation and testability:

```ruby
def process_paper_application
  Current.paper_context = true
  begin
    # Service logic that bypasses online validations
    process_application
  ensure
    Current.reset
  end
end
```

**Current Attributes Available**:
- `Current.paper_context` - Bypasses proof validations for paper applications
- `Current.skip_proof_validation` - General proof validation bypass
- `Current.resubmitting_proof` - Indicates proof resubmission context
- `Current.reviewing_single_proof` - Single proof review mode
- `Current.force_notifications` - Forces notification delivery in tests

**Used by**:
- `ProofConsistencyValidation#skip_proof_validation?`
- `ProofManageable#verify_proof_attachments`
- `ProofManageable#require_proof_validations?`

**Benefits over Thread-local**:
- Automatic cleanup between requests
- Better test isolation
- Rails-native approach
- Consistent state management

### Error Handling Pattern

Services use consistent error handling:

```ruby
def perform_operation
  ActiveRecord::Base.transaction do
    return add_error('Validation failed') unless valid?
    
    perform_core_logic
    true
  end
rescue StandardError => e
  log_error(e, 'Operation context')
  add_error(e.message)
  false
end
```

### Result Objects

Complex services return structured results:

```ruby
def attach_proof(...)
  result = { success: false, error: nil, duration_ms: 0 }
  start_time = Time.current
  
  begin
    # Service logic
    result[:success] = true
  rescue StandardError => e
    result[:error] = e
  ensure
    result[:duration_ms] = ((Time.current - start_time) * 1000).round
  end
  
  result
end
```

## Guardian/Dependent Handling

Services properly handle guardian/dependent relationships:

```ruby
# In PaperApplicationService
def process_constituent
  if applicant_type == 'dependent'
    # Handle guardian creation/lookup
    @guardian_user_for_app = find_or_create_guardian
    
    # Handle dependent creation with guardian's contact info if needed
    @constituent = create_dependent_with_guardian_info
    
    # Create GuardianRelationship
    GuardianRelationship.create!(
      guardian_user: @guardian_user_for_app,
      dependent_user: @constituent,
      relationship_type: relationship_type
    )
  else
    # Handle self-applicant
    @constituent = find_or_create_self_applicant
  end
end
```

## Testing Services

### Unit Testing Pattern

```ruby
class ServiceTest < ActiveSupport::TestCase
  setup do
    @admin = create(:admin)
    @application = create(:application)
  end

  test 'successful operation' do
    service = MyService.new(application: @application, admin: @admin)
    
    assert service.perform
    assert_empty service.errors
    
    # Verify expected changes
    @application.reload
    assert_equal 'expected_status', @application.status
  end

  test 'handles errors gracefully' do
    # Set up error condition
    @application.stubs(:save).returns(false)
    
    service = MyService.new(application: @application, admin: @admin)
    
    assert_not service.perform
    assert_includes service.errors, 'Expected error message'
  end
end
```

### Integration Testing

```ruby
test 'paper application service creates complete application' do
  params = {
    applicant_type: 'dependent',
    relationship_type: 'Parent',
    guardian_attributes: { ... },
    dependent_attributes: { ... },
    application: { ... }
  }
  
  service = Applications::PaperApplicationService.new(
    params: params,
    admin: @admin
  )
  
  assert_difference ['Application.count', 'GuardianRelationship.count'] do
    assert service.create
  end
  
  application = service.application
  assert application.for_dependent?
  assert_equal @admin.id, application.managing_guardian_id
end
```

## Future Service Candidates

Areas that could benefit from service object extraction:

1. **Voucher Management** - Complex voucher issuance and tracking logic
2. **Application Status Transitions** - State machine-like status changes
3. **User Verification Processes** - Multi-step verification workflows
4. **Notification Orchestration** - Complex notification routing and delivery
5. **Report Generation** - Complex data aggregation and formatting

## Service Guidelines

### When to Create a Service

Create a service when:
- Logic spans multiple models
- Complex business rules need encapsulation
- Operations need transaction management
- Error handling is complex
- Background job coordination is needed

### Service Responsibilities

Services should:
- Encapsulate business logic
- Handle error conditions gracefully
- Maintain audit trails
- Coordinate model interactions
- Provide clear success/failure indicators

### What Services Should Not Do

Avoid:
- Direct view rendering
- Session management
- HTTP request/response handling
- Complex parameter parsing (use form objects)
- Direct database queries (use models/scopes) 