# MAT Vulcan Application Workflow Guide

**Last Updated:** December 2025  
**Status:** Current and Accurate

This document provides a complete and accurate overview of how applications flow through the MAT Vulcan system, from initial submission through final approval and voucher issuance. **This documentation has been verified against the actual codebase implementation.**

## Table of Contents

1. [System Overview](#system-overview)
2. [Application Creation Flows](#application-creation-flows)
3. [Event System & Deduplication](#event-system--deduplication)
4. [Notification System](#notification-system)
5. [Proof Review Process](#proof-review-process)
6. [Medical Certification Workflow](#medical-certification-workflow)
7. [Application Status Management](#application-status-management)
8. [Guardian/Dependent Relationships](#guardiandependent-relationships)
9. [Voucher Assignment & Completion](#voucher-assignment--completion)
10. [Administrative Tools](#administrative-tools)
11. [Integration Points](#integration-points)

---

## System Overview

The MAT Vulcan system processes applications for assistive technology vouchers through two primary pathways:

1. **Constituent Portal Flow**: Online self-service applications by constituents
2. **Paper Application Flow**: Admin-processed applications from paper submissions

Both flows converge into a unified application management system with comprehensive tracking, notifications, and audit trails.

### Key Architectural Components

- **Applications::EventDeduplicationService**: Centralized event deduplication with 1-minute time windows and priority-based selection
- **NotificationService**: Multi-channel communication (email, SMS, in-app) with delivery tracking
- **Current Attributes Context**: Paper application validation bypassing using `Current.paper_context`
- **GuardianRelationship Model**: Explicit guardian/dependent management
- **MedicalCertificationAttachmentService**: Unified medical certification file handling and status management
- **ProofAttachmentService**: Proof document processing and validation

---

## Application Creation Flows

### Constituent Portal Flow

#### 1. User Registration & Authentication
```
User visits portal → Registration/Login → Dashboard → "Create Application"
```

**Key Components:**
- `ConstituentPortal::ApplicationsController`
- `ApplicationForm` (validation object)
- `Applications::ApplicationCreator` (service)

#### 2. Application Form Completion

**Form Sections:**
1. **Applicant Type Selection**
   - Self-application (adult applying for themselves)
   - Dependent application (guardian applying for minor/dependent)

2. **Personal Information**
   - Contact details (email, phone, address)
   - Demographic information
   - Disability declarations

3. **Household & Income**
   - Household size validation
   - Annual income with real-time FPL threshold checking
   - JavaScript validation prevents over-income submissions

4. **Medical Provider Information**
   - Provider contact details for medical certification
   - Medical information release authorization

5. **Proof Document Uploads**
   - Income proof (tax returns, benefit letters, etc.)
   - Residency proof (utility bills, lease agreements, etc.)
   - Real-time file validation using `ActiveStorageValidatable` concern

#### 3. Application Processing Logic

```ruby
# ApplicationCreator service pattern
def create_application
  ActiveRecord::Base.transaction do
    # 1. Validate form data
    validate_application_data
    
    # 2. Create or update user record
    user = find_or_create_user
    
    # 3. Handle guardian relationships (if dependent application)
    setup_guardian_relationship if dependent_application?
    
    # 4. Create application record
    application = create_application_record(user)
    
    # 5. Process proof attachments via ProofAttachmentService
    attach_proof_documents(application)
    
    # 6. Create audit events using AuditEventService
    log_application_creation(application)
    
    # 7. Send notifications via NotificationService
    notify_relevant_parties(application)
  end
end
```

#### 4. Real-Time Features

- **Autosave**: Form data saved every 2 seconds via `autosave_controller.js`
- **Income Validation**: AJAX validation against FPL thresholds
- **File Upload**: Progressive enhancement with drag-and-drop support
- **Status Updates**: Real-time progress indicators

### Paper Application Flow

#### 1. Admin Interface Access
```
Admin login → Admin Dashboard → "Paper Applications" → Create New
```

**Key Components:**
- `Admin::PaperApplicationsController`
- `Applications::PaperApplicationService`
- `Current.paper_context` validation bypassing

#### 2. Paper Application Processing

**Context Setting:**
```ruby
# Critical for bypassing online validations
Current.paper_context = true
begin
  # Paper application logic
  process_paper_application
ensure
  Current.reset
end
```

**Form Sections:**
1. **Applicant Type**
   - Radio buttons for self vs dependent applications
   - Dynamic form sections based on selection

2. **Guardian Management** (for dependents)
   - Search existing guardians by name/email/phone
   - Create new guardian with full contact information
   - Relationship type selection (Parent, Legal Guardian, etc.)

3. **Applicant Information**
   - Full demographic data entry
   - Disability type selection
   - Contact information strategies for dependents

4. **Application Details**
   - Household size and income entry
   - Medical provider information
   - Administrative notes and context

5. **Proof Document Processing**
   - **Accept with Upload**: Scan and approve documents simultaneously
   - **Accept without Upload**: Mark as approved for paper context
   - **Reject**: Select rejection reason and add notes

#### 3. Guardian/Dependent Logic

```ruby
# Guardian relationship creation
def process_guardian_relationship
  if params[:applicant_type] == 'dependent'
    # Find or create guardian
    guardian = find_existing_guardian || create_new_guardian
    
    # Create dependent user
    dependent = create_dependent_user
    
    # Establish relationship
    GuardianRelationship.create!(
      guardian_user: guardian,
      dependent_user: dependent,
      relationship_type: params[:relationship_type]
    )
    
    # Set application associations
    application.user = dependent  # Actual applicant
    application.managing_guardian = guardian  # Who manages it
  end
end
```

#### 4. Validation Bypassing

Paper applications bypass certain online validations:

```ruby
# In ProofConsistencyValidation concern
def skip_proof_validation?
  Current.paper_context?
end

# In ProofManageable concern
def require_proof_validations?
  return false if Current.paper_context?
  # ... other validation logic
end
```

---

## Event System & Deduplication

### Applications::EventDeduplicationService

**NEW ARCHITECTURE - Centralized Deduplication**

The system uses a single, robust deduplication service that consolidates previously competing systems and provides consistent event processing.

#### Core Features

**Time-Window Deduplication:**
```ruby
# 1-minute deduplication windows using proper bucketing
DEDUPLICATION_WINDOW = 1.minute

def deduplicate(events)
  grouped_events = events.group_by do |event|
    [
      event_fingerprint(event),
      (event.created_at.to_i / DEDUPLICATION_WINDOW) * DEDUPLICATION_WINDOW
    ]
  end

  grouped_events.values.map do |group|
    select_best_event(group)
  end.sort_by(&:created_at).reverse
end
```

**Event Fingerprinting:**
```ruby
def event_fingerprint(event)
  action = generic_action(event)
  
  details = case event
  when ApplicationStatusChange
    if event.metadata&.[](:change_type) == 'medical_certification'
      nil  # Group medical cert events together
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

**Priority-Based Selection:**
```ruby
def priority_score(event)
  case event
  when ApplicationStatusChange then 3  # Highest priority
  when Event then 2                   # Medium priority  
  when Notification then 1            # Lowest priority
  else 0
  end
end
```

#### Service Usage

```ruby
# Used by AuditLogBuilder for admin views
service = Applications::EventDeduplicationService.new
deduplicated = service.deduplicate([notifications, events, status_changes].flatten)

# Used by CertificationEventsService for medical certification display
certification_events = service.deduplicate(certification_related_events)

# Used by Activity model for constituent portal display
deduplicated_submissions = service.deduplicate(submission_events)
```

### Event Creation Patterns

**Standard Event Creation:**
```ruby
# Using AuditEventService for consistency
AuditEventService.log(
  action: 'application_status_changed',
  actor: current_user,
  auditable: application,
  metadata: {
    from_status: 'draft',
    to_status: 'in_progress',
    changed_by: admin.id
  }
)

# Direct Event creation (legacy pattern)
Event.create!(
  user: applicant,
  action: 'income_proof_submitted',
  auditable: application,
  metadata: {
    proof_type: 'income',
    submission_method: 'web',
    file_name: 'tax_return.pdf',
    ip_address: request.remote_ip
  }
)
```

---

## Notification System

### Multi-Channel Architecture

The notification system delivers messages through multiple channels with comprehensive tracking.

#### Notification Creation

```ruby
# Core notification creation
notification = NotificationService.create_and_deliver!(
  type: 'application_submitted',
  recipient: application.user,
  actor: current_user,
  notifiable: application,
  metadata: {
    application_id: application.id,
    submission_method: 'web'
  }
)
```

#### Delivery Channels

**1. In-App Notifications**
- Real-time display in user dashboards
- Read/unread status tracking
- Persistent until explicitly dismissed

**2. Email Notifications**
- Postmark integration with webhook tracking
- Delivery confirmation and bounce handling
- Template-based HTML and text versions

**3. SMS Notifications**
- Twilio integration for urgent notifications
- Phone number validation and formatting
- Delivery status tracking

**4. Fax Notifications** (Medical Providers)
- Medical certification requests via fax
- Fallback to email if fax unavailable
- Provider communication preferences

#### Notification Types

```ruby
# Application lifecycle notifications
'application_submitted'         # Confirmation to applicant
'application_approved'          # Approval notification
'application_rejected'          # Rejection with reasons
'proof_review_needed'          # Admin notification for review
'proof_approved'               # Proof approval confirmation
'proof_rejected'               # Proof rejection with feedback
'medical_certification_requested'  # Provider notification
'evaluator_assigned'           # Evaluation scheduling
'voucher_assigned'             # Voucher issuance
```

#### Notification Metadata

```ruby
{
  application_id: 123,
  proof_type: 'income',           # For proof-related notifications
  rejection_reason: 'unclear',    # For rejections
  provider_contact: 'fax',        # Delivery method preference
  evaluation_type: 'hearing',     # For evaluator assignments
  voucher_amount: 500.00,         # For voucher notifications
  appointment_date: '2025-01-15'  # For scheduling
}
```

### Webhook Processing

**Email Event Handling:**
```ruby
# app/controllers/webhooks/email_events_controller.rb
def create
  case params[:record_type]
  when 'Delivery'
    handle_delivery_confirmation
  when 'Bounce'
    handle_bounce_event
  when 'SpamComplaint'
    handle_spam_complaint
  end
end
```

**Bounce Handling:**
```ruby
def handle_bounce_event
  notification = find_notification_by_message_id
  notification.update!(
    delivery_status: 'bounced',
    delivery_error: params[:description]
  )
  
  # Flag user email as problematic
  user = notification.recipient
  user.update!(email_bounced: true)
end
```

---

## Proof Review Process

### Unified Proof Management

All proof processing flows through the `ProofAttachmentService` for consistency across submission methods.

#### File Upload & Processing

```ruby
# Core attachment processing
result = ProofAttachmentService.attach_proof(
  application: application,
  proof_type: 'income',           # 'income' or 'residency'
  blob_or_file: uploaded_file,
  status: :not_reviewed,          # Initial status
  admin: admin_user,              # For paper applications
  submission_method: :web,        # :web, :paper, :email, :fax
  metadata: {
    ip_address: request.remote_ip,
    original_filename: file.original_filename
  }
)
```

#### Admin Review Interface

**Review Process via Admin::ApplicationsController:**
```ruby
def update_proof_status
  admin_user = validate_and_prepare_admin_user

  # Use ProofReviewService for consistent processing
  service = ProofReviewService.new(@application, admin_user, params)
  result = service.call

  if result.success?
    handle_successful_review
  else
    handle_review_error(result)
  end
end
```

**Approval Process:**
```ruby
# ProofReviewService handles approval
def approve_proof(proof_type)
  ActiveRecord::Base.transaction do
    # 1. Update proof status
    application.update!("#{proof_type}_proof_status" => 'approved')
    
    # 2. Create approval event via AuditEventService
    AuditEventService.log(
      action: "#{proof_type}_proof_approved",
      actor: admin,
      auditable: application,
      metadata: { reviewed_by: admin.id }
    )
    
    # 3. Check for auto-approval (via ApplicationStatusManagement concern)
    application.check_auto_approval_eligibility
    
    # 4. Notify applicant via NotificationService
    NotificationService.create_and_deliver!(
      type: 'proof_approved',
      recipient: application.user,
      notifiable: application,
      metadata: { proof_type: proof_type }
    )
  end
end
```

**Rejection Process:**
```ruby
def reject_proof(proof_type, reason, notes)
  ActiveRecord::Base.transaction do
    # 1. Update proof status and reasons
    application.update!(
      "#{proof_type}_proof_status" => 'rejected',
      "#{proof_type}_proof_rejection_reason" => reason,
      "#{proof_type}_proof_rejection_notes" => notes
    )
    
    # 2. Create rejection event
    AuditEventService.log(
      action: "#{proof_type}_proof_rejected",
      actor: admin,
      auditable: application,
      metadata: {
        reason: reason,
        notes: notes,
        reviewed_by: admin.id
      }
    )
    
    # 3. Notify applicant with resubmission instructions
    NotificationService.create_and_deliver!(
      type: 'proof_rejected',
      recipient: application.user,
      notifiable: application,
      metadata: {
        proof_type: proof_type,
        reason: reason,
        resubmission_required: true
      }
    )
  end
end
```

#### Multiple Submission Methods

**Email-Based Proof Submission:**
```ruby
# ProofSubmissionMailbox processes incoming emails
class ProofSubmissionMailbox < ApplicationMailbox
  def process
    mail.attachments.each do |attachment|
      proof_type = determine_proof_type(attachment.filename)
      
      # Create blob from email attachment
      blob = ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(attachment.body.decoded),
        filename: attachment.filename,
        content_type: attachment.content_type
      )
      
      # Process through unified service
      ProofAttachmentService.attach_proof(
        application: application,
        proof_type: proof_type,
        blob_or_file: blob,
        status: :not_reviewed,
        submission_method: :email,
        metadata: {
          sender_email: mail.from.first,
          email_subject: mail.subject,
          received_at: Time.current
        }
      )
    end
  end
end
```

**File Type Determination:**
```ruby
def determine_proof_type(filename)
  filename = filename.downcase
  
  case filename
  when /income|tax|pay|salary|wage|benefit|ss[ia]/
    'income'
  when /address|utility|lease|rent|residen/
    'residency'
  when /medical|doctor|physician|certification/
    'medical_certification'
  else
    'income' # Default, admin can reassign
  end
end
```

---

## Medical Certification Workflow

### Certification Request Process

Medical certification follows a structured workflow with multi-channel provider communication.

#### Request Initiation

```ruby
# Applications::MedicalCertificationService
class MedicalCertificationService < BaseService
  def request_certification
    # 1. Update application status using update_columns to avoid validation conflicts
    application.update_columns(
      medical_certification_status: 'requested',
      medical_certification_request_count: application.medical_certification_request_count + 1,
      medical_certification_requested_at: Time.current
    )
    
    # 2. Create notification for tracking
    notification = create_notification(Time.current)
    
    # 3. Queue email delivery via background job
    send_email(notification)
    
    true
  rescue StandardError => e
    log_error(e, 'Failed to request certification')
    false
  end
end
```

#### Medical Certification Document Processing

**MedicalCertificationAttachmentService - Core Service:**
```ruby
# Attach new certification file
def self.attach_certification(application:, blob_or_file:, status: :approved, 
                             admin: nil, submission_method: :admin_upload, metadata: {})
  result = { success: false, error: nil, duration_ms: 0 }
  
  begin
    # 1. Process blob_or_file parameter (handles various input types)
    attachment_param = process_attachment_param(blob_or_file)
    
    # 2. Direct attachment to fresh application instance
    fresh_application = Application.unscoped.find(application.id)
    fresh_application.medical_certification.attach(attachment_param)
    
    # 3. Verify attachment succeeded
    verify_attachment(fresh_application)
    
    # 4. Update status and create audit records in transaction
    update_certification_status_only(application, status, admin, submission_method, metadata)
    
    result[:success] = true
    result[:status] = status.to_s
  rescue StandardError => e
    record_failure(application, e, admin, submission_method, metadata)
    result[:error] = e
  end
  
  result
end

# Update status without file attachment
def self.update_certification_status(application:, status:, admin:, submission_method: :admin_review, metadata: {})
  # Similar pattern but only updates status fields without touching attachment
  update_certification_status_only(application, status, admin, submission_method, metadata)
end

# Reject certification with reason
def self.reject_certification(application:, admin:, reason:, notes: nil, 
                             submission_method: :admin_review, metadata: {})
  ActiveRecord::Base.transaction do
    # Update status and create comprehensive audit trail
    application.update!(
      medical_certification_status: 'rejected',
      medical_certification_verified_at: Time.current,
      medical_certification_verified_by_id: admin.id,
      medical_certification_rejection_reason: reason
    )
    
    # Create ApplicationStatusChange, Event, and Notification records
    create_comprehensive_audit_trail(application, admin, reason, notes)
  end
end
```

#### Email-Based Medical Certification

**Medical Certification Mailbox:**
```ruby
# MedicalCertificationMailbox processes provider submissions
class MedicalCertificationMailbox < ApplicationMailbox
  before_processing :ensure_medical_provider
  before_processing :ensure_valid_certification_request
  before_processing :validate_attachments

  def process
    # Create audit record
    audit = create_audit_record
    
    # Process each attachment
    mail.attachments.each do |attachment|
      attach_certification(attachment, audit)
    end
    
    # Create status change record for consistency
    create_status_change_record
    
    # Notify admin and constituent
    notify_admin
    notify_constituent
  end
  
  private
  
  def attach_certification(attachment, _audit)
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(attachment.body.decoded),
      filename: attachment.filename,
      content_type: attachment.content_type
    )
    
    application.medical_certification.attach(blob)
  end
end
```

#### Admin Review Process

**Controller Actions (Admin::ApplicationsController):**
```ruby
def update_certification_status
  status = @application.normalize_certification_status(params[:status])
  update_type = @application.determine_certification_update_type(status, params)

  case update_type
  when :rejection
    process_certification_rejection
  when :status_update
    update_existing_certification_status(status)
  when :new_upload
    upload_new_certification(status)
  end
end

def process_certification_rejection
  reviewer = Applications::MedicalCertificationReviewer.new(@application, current_user)
  result = reviewer.reject(
    rejection_reason: params[:rejection_reason],
    notes: params[:notes]
  )
  
  if result.success?
    redirect_with_notice('Medical certification rejected and provider notified.')
  else
    redirect_with_alert("Failed to reject certification: #{result.message}")
  end
end
```

#### Auto-Approval Logic

Applications can be auto-approved when all requirements are met:

```ruby
# ApplicationStatusManagement concern
def check_auto_approval_eligibility
  return unless all_requirements_met?
  
  if income_proof_approved? && 
     residency_proof_approved? && 
     medical_certification_approved? &&
     within_income_threshold?
    
    update!(status: :approved)
    trigger_voucher_assignment_if_eligible
  end
end
```

---

## Application Status Management

### Status Lifecycle

Applications progress through defined statuses with automatic transitions and manual admin controls.

#### Core Status Flow

```
draft → in_progress → approved/rejected
  ↓         ↓            ↓
autosave   reviews    voucher_assigned
```

**Status Definitions:**
- `draft`: Incomplete application, user can edit
- `in_progress`: Complete application, under admin review
- `approved`: All requirements met, ready for voucher assignment
- `rejected`: Application denied, requires resubmission
- `voucher_assigned`: Voucher issued to applicant

#### Status Change Processing

**Admin Status Override (Admin::ApplicationStatusProcessor concern):**
```ruby
def process_application_status_update(action)
  case action
  when :approve
    approve_application_with_audit
  when :reject
    reject_application_with_reason
  end
end

private

def approve_application_with_audit
  ApplicationStatusChange.create!(
    application: @application,
    user: current_user,
    from_status: @application.status,
    to_status: 'approved',
    reason: 'Manual admin approval'
  )
  
  @application.update!(status: :approved)
  
  # Trigger voucher assignment if eligible
  @application.check_voucher_assignment_eligibility
end
```

#### Auto-Approval Triggers

```ruby
# Called after proof approvals and medical certification updates
def check_application_completion
  return unless application_ready_for_auto_approval?
  
  if all_proofs_approved? && medical_certification_approved?
    auto_approve_application
  end
end
```

---

## Guardian/Dependent Relationships

### Relationship Model Structure

The system uses explicit `GuardianRelationship` records to manage guardian/dependent associations.

#### Relationship Creation Process

```ruby
# During dependent application creation
def create_guardian_relationship
  # 1. Ensure guardian user exists
  guardian = find_or_create_guardian_user
  
  # 2. Create dependent user
  dependent = create_dependent_user
  
  # 3. Establish explicit relationship
  GuardianRelationship.create!(
    guardian_user: guardian,
    dependent_user: dependent,
    relationship_type: params[:relationship_type]
  )
  
  # 4. Set application associations correctly
  application.user = dependent           # Actual applicant
  application.managing_guardian = guardian  # Who manages the application
end
```

#### Contact Information Strategy

```ruby
# Flexible contact handling for dependents
case params[:email_strategy]
when 'guardian'
  dependent.email = generate_system_email(dependent)
  dependent.dependent_email = guardian.email
when 'dependent'
  dependent.email = params[:dependent_email]
  dependent.dependent_email = params[:dependent_email]
end

# Effective contact resolution in User model
def effective_email
  dependent_email.present? ? dependent_email : email
end
```

#### Guardian Dashboard Management

```ruby
# Guardian can view all dependent applications
def guardian_dashboard
  @managed_applications = current_user.managed_applications.includes(:user)
  @dependents = current_user.dependents.includes(:applications)
  
  # Grouped by status for easier management
  @applications_by_status = @managed_applications.group_by(&:status)
end
```

### Notification Routing

```ruby
# Notifications go to managing guardian for dependent applications
def notification_recipient(application)
  if application.for_dependent?
    application.managing_guardian
  else
    application.user
  end
end
```

---

## Voucher Assignment & Completion

### Voucher Lifecycle Management

Once applications are approved, they enter the voucher assignment and fulfillment process.

#### Automatic Voucher Assignment

```ruby
def assign_voucher(application)
  voucher = Voucher.create!(
    application: application,
    user: application.user,
    amount: calculate_voucher_amount(application),
    status: :assigned,
    assigned_at: Time.current,
    expires_at: 1.year.from_now
  )
  
  # Notify recipient via NotificationService
  NotificationService.create_and_deliver!(
    type: 'voucher_assigned',
    recipient: voucher_recipient(application),
    notifiable: voucher,
    metadata: {
      voucher_amount: voucher.amount,
      expiration_date: voucher.expires_at
    }
  )
end
```

#### Voucher Redemption Process

```ruby
# Vendor portal integration
def redeem_voucher(voucher, products, vendor)
  ActiveRecord::Base.transaction do
    # 1. Validate voucher and products
    validate_voucher_redemption(voucher, products)
    
    # 2. Create transaction records
    transaction = VoucherTransaction.create!(
      voucher: voucher,
      vendor: vendor,
      products: products,
      total_amount: products.sum(&:price),
      transaction_date: Time.current
    )
    
    # 3. Update voucher status
    voucher.update!(
      status: :redeemed,
      redeemed_at: Time.current,
      redeemed_by: vendor
    )
    
    # 4. Generate invoice for vendor
    Invoice.create!(
      vendor: vendor,
      voucher_transaction: transaction,
      amount: transaction.total_amount,
      status: :pending
    )
  end
end
```

---

## Administrative Tools

### Dashboard and Application Management

#### Admin::ApplicationsController Features

**Application Filtering and Search:**
```ruby
def filtered_scope(scope)
  result = Applications::FilterService.new(scope, params).apply_filters
  result.is_a?(BaseService::Result) ? result.data : scope
end

def base_scope
  Application
    .includes(:user, :managing_guardian)
    .distinct
    .then { |rel| params[:status].present? ? rel : rel.where.not(status: %i[rejected archived]) }
end
```

**Metrics Loading:**
```ruby
def load_dashboard_metrics
  # Direct database counts for primary metrics
  @open_applications_count = Application.active.count
  @pending_services_count = Application.where(status: :approved).count
  
  # Additional metrics from reporting service
  service_result = Applications::ReportingService.new.generate_index_data
  
  # Common tasks counts
  @proofs_needing_review_count = Application.where(income_proof_status: :not_reviewed)
                                           .or(Application.where(residency_proof_status: :not_reviewed))
                                           .distinct.count
  
  @medical_certs_to_review_count = Application.where.not(status: %i[rejected archived])
                                             .where(medical_certification_status: :received)
                                             .count
end
```

#### Bulk Operations

```ruby
def batch_approve
  result = Application.batch_update_status(params[:ids], :approved)
  if result
    redirect_to admin_applications_path, notice: 'Applications approved.'
  else
    render json: { error: 'Unable to approve applications' },
           status: :unprocessable_entity
  end
end
```

### Audit Trail and Reporting

#### Comprehensive Application History

```ruby
# Applications::AuditLogBuilder provides unified audit log building
def build_deduplicated_audit_logs
  # Collect all events from various sources
  events = [
    load_proof_reviews,
    load_status_changes,
    load_notifications,
    load_application_events,
    load_user_profile_changes
  ].flatten

  # Use EventDeduplicationService for consistent deduplication
  EventDeduplicationService.new.deduplicate(events)
end
```

#### Admin Application Show View

```ruby
def show
  # Load application associations for show view
  load_application_associations_for_show
  
  # Preload proof history data
  @proof_histories = {
    income: load_proof_history(:income),
    residency: load_proof_history(:residency)
  }
  
  # Use CertificationEventsService for medical certification display
  certification_service = Applications::CertificationEventsService.new(@application)
  @certification_events = certification_service.certification_events
  @certification_requests = certification_service.request_events
  
  # Training session management
  @max_training_sessions = Policy.get('max_training_sessions').to_i
  @completed_training_sessions_count = calculate_completed_sessions
end
```

---

## Integration Points

### External System Integration

**Email Service (Postmark):**
- Webhook endpoints for delivery tracking via `webhooks/email_events_controller`
- Bounce and complaint handling
- Template management through NotificationService

**SMS Service (Twilio):**
- Delivery confirmation tracking
- Phone number validation and formatting
- International number support

**Document Storage (ActiveStorage):**
- File validation using `ActiveStorageValidatable` concern
- Virus scanning integration via background jobs
- Secure access controls with signed URLs

### Webhook Receivers

```ruby
# Email events from Postmark
POST /webhooks/email_events
# Medical certification submissions
POST /webhooks/medical_certifications
# Document processing callbacks
POST /webhooks/document_events
```

### Service Architecture

**Core Services:**
- `Applications::EventDeduplicationService` - Centralized event deduplication
- `Applications::AuditLogBuilder` - Unified audit log construction
- `Applications::CertificationEventsService` - Medical certification event processing
- `MedicalCertificationAttachmentService` - Medical document processing
- `ProofAttachmentService` - Proof document processing
- `NotificationService` - Multi-channel notifications
- `AuditEventService` - Standardized event logging

---

This comprehensive guide accurately reflects the current implementation of the MAT Vulcan application workflow system. Each component has been verified against the actual codebase to ensure documentation accuracy.

For technical implementation details, refer to the individual service and controller files in the codebase. 