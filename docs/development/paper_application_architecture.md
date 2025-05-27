# Paper Application Architecture

## Overview

The paper application system allows administrators to create applications on behalf of constituents. It uses a service-based architecture with proper thread-local context to bypass online validation requirements.

## Core Components

### Applications::PaperApplicationService

The main service handling paper application creation and updates:

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

**Key Responsibilities**:
- Process constituent creation/lookup (both guardian and dependent scenarios)
- Create GuardianRelationship records for dependent applications
- Handle proof uploads and rejections
- Set proper thread-local context for validation bypassing
- Create audit trails and notifications

### Admin::PaperApplicationsController

Handles the web interface for paper applications:

```ruby
def create
  service_params = paper_application_processing_params
  service = Applications::PaperApplicationService.new(
    params: service_params,
    admin: current_user
  )

  if service.create
    redirect_to admin_application_path(service.application),
                notice: generate_success_message(service.application)
  else
    handle_service_failure(service)
  end
end
```

**Features**:
- Handles both self-applicant and guardian/dependent scenarios
- Processes proof acceptance/rejection
- Manages guardian search and creation
- Provides FPL threshold validation

## Thread-Local Context

### Purpose
Paper applications need to bypass certain validations that apply to online submissions:
- `ProofConsistencyValidation` - Requires proof attachments for approved/rejected status
- `ProofManageable` - Validates proof attachments on save

### Implementation
```ruby
def process_paper_application
  Thread.current[:paper_application_context] = true
  begin
    # Paper application logic that bypasses online validations
    create_application
    process_proofs
  ensure
    Thread.current[:paper_application_context] = nil
  end
end
```

### Validation Checks
```ruby
# In ProofConsistencyValidation
def skip_proof_validation?
  Thread.current[:paper_application_context].present?
end

# In ProofManageable  
def require_proof_validations?
  return false if Thread.current[:paper_application_context]
  # ... other validation logic
end
```

## Guardian/Dependent Handling

### Self-Applicant Flow
1. Admin fills out application form for adult constituent
2. Service creates/finds User record
3. Application created with `user_id` set to constituent
4. `managing_guardian_id` remains nil

### Dependent Application Flow
1. Admin selects "dependent" applicant type
2. Admin either selects existing guardian or creates new one
3. Admin fills out dependent information
4. Service creates GuardianRelationship linking guardian and dependent
5. Application created with:
   - `user_id` set to dependent (the actual applicant)
   - `managing_guardian_id` set to guardian

### Guardian Search and Creation
```ruby
# Existing guardian selection
guardian_id = params[:guardian_id]
@guardian_user_for_app = User.find(guardian_id)

# New guardian creation
guardian_attrs = params[:guardian_attributes]
@guardian_user_for_app = create_new_user(guardian_attrs, is_managing_adult: true)

# Create relationship
GuardianRelationship.create!(
  guardian_user: @guardian_user_for_app,
  dependent_user: @constituent,
  relationship_type: params[:relationship_type]
)
```

## Proof Processing

### Proof Acceptance
```ruby
def process_accept_proof(type)
  if file_present?
    # Upload file and set status to approved
    result = ProofAttachmentService.attach_proof(
      application: @application,
      proof_type: type,
      blob_or_file: file_or_signed_id,
      status: :approved,
      admin: @admin,
      submission_method: :paper
    )
  else
    # Paper context: Mark as approved without file
    @application.update_column(
      "#{type}_proof_status",
      Application.public_send("#{type}_proof_statuses")['approved']
    )
  end
end
```

### Proof Rejection
```ruby
def process_reject_proof(type)
  result = ProofAttachmentService.reject_proof_without_attachment(
    application: @application,
    proof_type: type,
    admin: @admin,
    reason: params["#{type}_proof_rejection_reason"],
    notes: params["#{type}_proof_rejection_notes"],
    submission_method: :paper
  )
end
```

## Form Architecture

### JavaScript Controllers
- **`paper_application_controller.js`** - Main form coordinator, income validation
- **`applicant_type_controller.js`** - Handles adult vs dependent views
- **`dependent_fields_controller.js`** - Manages dependent-specific fields
- **`guardian_picker_controller.js`** - Coordinates guardian search/selection
- **`document_proof_handler_controller.js`** - Manages proof acceptance/rejection

### Form Sections
1. **Applicant Type Selection** - Self vs dependent radio buttons
2. **Guardian Information** - Search existing or create new guardian
3. **Applicant Information** - Constituent details and disabilities
4. **Application Details** - Household size, income, medical provider
5. **Proof Documents** - Accept/reject income and residency proofs

## Data Flow

### Parameter Structure
```ruby
{
  applicant_type: 'dependent',
  relationship_type: 'Parent',
  guardian_id: 123, # OR guardian_attributes for new guardian
  dependent_attributes: {
    first_name: 'Child',
    last_name: 'Doe',
    date_of_birth: '2010-01-01',
    # ... other fields
  },
  application: {
    household_size: 3,
    annual_income: 25000,
    # ... other application fields
  },
  income_proof_action: 'accept',
  income_proof: uploaded_file, # OR income_proof_signed_id
  residency_proof_action: 'reject',
  residency_proof_rejection_reason: 'insufficient_documentation'
}
```

### Processing Flow
1. **Validate Parameters** - Check required fields and FPL thresholds
2. **Process Guardian** - Create/find guardian user if dependent application
3. **Process Applicant** - Create/find the actual applicant user
4. **Create Relationship** - Link guardian and dependent if applicable
5. **Create Application** - Build application with proper user associations
6. **Process Proofs** - Handle proof uploads/rejections
7. **Create Audits** - Log events and proof submissions
8. **Send Notifications** - Notify relevant parties

## Testing Considerations

### Thread-Local Context
Always set context in paper application tests:
```ruby
setup do
  Thread.current[:paper_application_context] = true
end

teardown do
  Thread.current[:paper_application_context] = nil
end
```

### Guardian Relationship Testing
```ruby
test 'creates guardian relationship for dependent application' do
  params = {
    applicant_type: 'dependent',
    relationship_type: 'Parent',
    guardian_attributes: guardian_attrs,
    dependent_attributes: dependent_attrs,
    application: application_attrs
  }
  
  assert_difference ['GuardianRelationship.count', 'Application.count'] do
    service = Applications::PaperApplicationService.new(params: params, admin: @admin)
    assert service.create
  end
  
  application = service.application
  assert application.for_dependent?
  assert_equal service.guardian_user_for_app.id, application.managing_guardian_id
end
```

### Proof Processing Testing
```ruby
test 'accepts proof without file in paper context' do
  params = {
    income_proof_action: 'accept',
    # No income_proof file provided
  }
  
  service = Applications::PaperApplicationService.new(params: params, admin: @admin)
  assert service.update(@application)
  
  @application.reload
  assert @application.income_proof_status_approved?
  assert_not @application.income_proof.attached?
end
```

## Error Handling

### Service Errors
```ruby
def handle_service_failure(service, existing_application = nil)
  if service.errors.any?
    error_message = service.errors.join('; ')
    flash.now[:alert] = error_message
  end
  
  # Repopulate form data for re-rendering
  @paper_application = {
    application: service.application || existing_application || Application.new,
    constituent: service.constituent || Constituent.new,
    guardian_user_for_app: service.guardian_user_for_app,
    submitted_params: params.to_unsafe_h.slice(...)
  }
  
  render (existing_application ? :edit : :new), status: :unprocessable_entity
end
```

### Common Error Scenarios
- Invalid FPL thresholds
- Missing required fields for guardian/dependent
- Proof processing failures
- Guardian relationship creation errors
- User creation/validation failures

## Future Enhancements

### Planned Improvements
- **Form Object Pattern** - Extract form logic into dedicated form objects
- **Command Object Pattern** - Separate creation/update commands
- **Server-Side Validation** - Move validation logic from JavaScript to Rails
- **ViewComponents** - Extract repetitive form sections into components

### Current Limitations
- JavaScript handles some validation that should be server-side
- Form state management could be more robust
- Error handling could be more granular
- Some validation bypassing is manual rather than systematic 