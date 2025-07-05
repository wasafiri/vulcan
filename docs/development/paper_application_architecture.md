# Paper Application Architecture (Rails)

A concise reference for how the admin-only “paper” application path works and how to extend or test it safely.

---

## 1 · High-Level Flow

```
Admin → Admin::PaperApplicationsController → PaperApplicationService
            ↘ proofs (accept/reject) ↙
                     Audits / Notifications
```

* **Why a separate path?** Paper apps bypass online-only validations (proof uploads, attachment checks) while still preserving audit trails.

---

## 2 · Key Components

### 2.1 · Applications::PaperApplicationService

```ruby
service = Applications::PaperApplicationService.new(
  params: paper_application_params,
  admin:  current_user
)
service.create  # returns true/false
```

| Responsibility | Notes |
|----------------|-------|
| Constituent lookup / create | Handles self vs dependent applicants |
| GuardianRelationship | Creates & links guardian ↔ dependent |
| Proof processing | Upload, accept w/o file, reject |
| Thread-local context | `Current.paper_context = true` |
| Audits & notifications | Standardised event logging |

---

### 2.2 · Admin::PaperApplicationsController

```ruby
def create
  service = Applications::PaperApplicationService
              .new(params: processed_params, admin: current_user)

  if service.create
    redirect_to admin_application_path(service.application),
                notice: "Paper application created."
  else
    render :new, status: :unprocessable_entity
  end
end
```

Handles web UI, guardian search/creation, proof buttons, and FPL checks.

---

## 3 · Thread-Local Context

```ruby
Current.paper_context = true
begin
  # create application, process proofs, etc.
ensure
  Current.reset
end
```

* Skips **ProofConsistencyValidation** and **ProofManageable**.
* Always reset in `ensure` or test teardown.

---

## 4 · Guardian / Dependent Logic

| Flow | Key Points |
|------|------------|
| **Self-applicant** | `managing_guardian_id` is `nil`. |
| **Dependent** | Guardian selected/created → `GuardianRelationship` made → app’s `managing_guardian_id` set. |

Guardian creation snippet:

```ruby
guardian = params[:guardian_id] ?
             User.find(params[:guardian_id]) :
             create_new_user(guardian_attrs, is_managing_adult: true)

GuardianRelationship.create!(
  guardian_user:  guardian,
  dependent_user: constituent,
  relationship_type: params[:relationship_type]
)
```

---

## 5 · Proof Processing

```ruby
# Accept (paper context allows no file)
@application.update_column(
  "#{type}_proof_status",
  Application.public_send("#{type}_proof_statuses")['approved']
)
```

```ruby
# Reject
ProofAttachmentService.reject_proof_without_attachment(
  application: @application,
  proof_type:  type,
  admin:       @admin,
  reason:      params["#{type}_proof_rejection_reason"],
  notes:       params["#{type}_proof_rejection_notes"],
  submission_method: :paper
)
```

---

## 6 · Form Front-End

| Stimulus Controller | Role |
|---------------------|------|
| `paper_application_controller` | Overall coordination / income check |
| `applicant_type_controller`    | Adult vs dependent toggle |
| `dependent_fields_controller`  | Dependent-only inputs |
| `guardian_picker_controller`   | Search & select/create guardian |
| `document_proof_handler_controller` | Accept / reject buttons |

Form sections (in order):

1. Applicant type  
2. Guardian info (if dependent)  
3. Applicant info  
4. Application details (household size, income, provider)  
5. Proof documents  

---

## 7 · Parameter Shape

```ruby
{
  applicant_type:   "dependent",
  relationship_type:"Parent",
  guardian_id:      123,           # or guardian_attributes
  guardian_attributes: { ... },
  constituent: { ... },            # applicant
  email_strategy:  "dependent",    # or "guardian"
  phone_strategy:  "guardian",
  address_strategy:"guardian",
  application: { household_size:3, annual_income:25_000 },
  income_proof_action:    "accept",
  residency_proof_action: "reject",
  # proof files or signed IDs may be included
}
```

Processing steps:

1. Validate & cast → **FPL threshold check**.  
2. Process guardian (if dependent).  
3. Process applicant.  
4. Apply contact strategies.  
5. Create GuardianRelationship.  
6. Build Application.  
7. Handle proofs.  
8. Audit & notify.

---

## 8 · Testing Guide

### 8.1 · Context Setup

```ruby
setup    { Current.paper_context = true }
teardown { Current.reset }
```

### 8.2 · Guardian Relationship

```ruby
assert_difference ['GuardianRelationship.count', 'Application.count'] do
  service = Applications::PaperApplicationService
              .new(params: dependent_params, admin: @admin)
  assert service.create
end
```

### 8.3 · Proof Acceptance w/o File

```ruby
service = Applications::PaperApplicationService
            .new(params: { income_proof_action: 'accept' }, admin: @admin)
assert service.update(@application)
assert @application.reload.income_proof_status_approved?
```

---

## 9 · Error Handling

```ruby
def handle_service_failure(service, existing_app = nil)
  flash.now[:alert] = service.errors.join('; ')
  @paper_application = {
    application:            service.application || existing_app || Application.new,
    constituent:            service.constituent || Constituent.new,
    guardian_user_for_app:  service.guardian_user_for_app,
    submitted_params:       params.to_unsafe_h.slice(...)
  }
  render(existing_app ? :edit : :new, status: :unprocessable_entity)
end
```

Typical failures: FPL too high, missing guardian data, proof issues, user validation errors.

---

## 10 · Current Implementation Details

The current implementation has the following characteristics:

*   **Validation**: Some validation logic resides in client-side JavaScript.
*   **Service Layer**: The `PaperApplicationService` handles the core creation and update logic, but the controller still performs significant processing.
*   **Views**: The form is rendered using ERB partials, which contain some repetitive logic.

Recent controller enhancements include:

*   Unified `constituent` parameters.
*   The addition of `email_strategy`, `phone_strategy`, and `address_strategy` to manage contact information.
*   Inference of dependent applications when `guardian_attributes` are present.
