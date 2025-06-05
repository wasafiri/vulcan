# Current Application Features

This document provides a comprehensive overview of the major features currently implemented in the MAT Vulcan application.

## Table of Contents
1. [Medical Certification System](#medical-certification-system)
2. [Proof Attachment System](#proof-attachment-system)
3. [Email Tracking](#email-tracking)
4. [Guardian Relationship System](#guardian-relationship-system)

---

## Medical Certification System

The medical certification system allows constituents to request certification of their disability from a medical provider. This certification is a critical part of the application process.

### Process Overview

1. A constituent applies for services and indicates they need a medical certification
2. An administrator sends a certification request to the constituent's medical provider
3. The medical provider completes the certification and returns it (via fax, email, mail, etc.)
4. An administrator uploads and approves the certification
5. The application progresses to the next step in the approval process

### Key Components

#### Models
- **Application**: Stores medical certification status, request count, and timestamps
- **Notification**: Tracks history of certification requests with metadata
- **GuardianRelationship**: Links guardian users to dependent users for applications

#### Services
- **Applications::MedicalCertificationService**: Handles the business logic for certification requests
  - Validates prerequisites (medical provider email required)
  - Updates application status and request count
  - Creates notifications for tracking
  - Schedules email delivery via background jobs
  - Handles error cases gracefully

- **MedicalCertificationAttachmentService**: Processes certification document uploads and status updates
  - Manages file attachments with transaction safety
  - Updates certification status (approved, rejected, received)
  - Creates comprehensive audit records (ApplicationStatusChange, Event, Notification)
  - Provides unified interface for all certification file operations
  - Handles both new uploads and status-only updates

- **Applications::MedicalCertificationReviewer**: Handles the review and rejection process
  - Validates certification documents
  - Manages rejection workflow with provider notifications
  - Updates application status based on review outcome
  - Coordinates with MedicalProviderNotifier for multi-channel communication

- **MedicalProviderNotifier**: Handles provider communication for rejections
  - Supports both fax and email notification channels
  - Prefers fax when available, falls back to email
  - Tracks delivery results and message IDs for audit trails

#### Jobs
- **MedicalCertificationEmailJob**: Background job for email delivery
  - Ensures reliable email delivery with retry capability
  - Accepts notification_id parameter for tracking
  - Decouples request processing from email delivery
  - Provides exponential backoff for SMTP errors

#### Mailboxes
- **MedicalCertificationMailbox**: Processes inbound email certifications
  - Validates sender as registered medical provider
  - Ensures valid certification request exists
  - Processes attachments and updates application status
  - Creates audit trails and notifies administrators

### Administrator Workflows

#### Requesting Certifications
1. Navigate to the application details page
2. Verify the medical provider information is correct
3. Click the "Request Medical Certification" button
4. Confirm the action

#### Uploading and Approving Certifications
1. Navigate to the application details page
2. Locate the "Upload Faxed Medical Certification" section
3. Select "Approve Certification and Upload"
4. Use the file picker to select the scanned certification document
5. Click "Process Certification"

#### Rejecting Certifications
1. Navigate to the application details page
2. Locate the "Upload Faxed Medical Certification" section
3. Select "Reject Certification"
4. Select a common rejection reason or enter a custom reason
5. Add additional notes if needed
6. Click "Process Certification"

### Technical Implementation

#### Certification Status Tracking
```ruby
class Application < ApplicationRecord
  enum medical_certification_status: {
    not_requested: 0,
    requested: 1,
    received: 2,
    approved: 3,
    rejected: 4
  }
end
```

#### Request History Tracking
- Each request creates a notification with metadata including timestamp and request number
- Views query the notification table to display the history
- Provides a reliable audit trail of all requests

---

## Proof Attachment System

The proof attachment system handles document uploads for residency and income verification through multiple channels: constituent portal, admin interface, email submissions, and faxed documents.

### System Architecture

#### Unified Service Approach
- All document attachments use the `ProofAttachmentService` regardless of submission method
- Provides consistent error handling, audit trails, and metrics for all file operations
- Centralizes file validation, attachment logic, and status updates

#### Transaction Safety
- All operations use `ActiveRecord::Base.transaction` for data integrity
- File attachment, status updates, and audit records are wrapped in transactions
- Ensures no partial updates occur that could leave the system in an inconsistent state

#### Standardized Metadata
All attachment operations include metadata:
```ruby
metadata: { 
  submission_method: :web, # or :paper, :email, :fax, etc.
  ip_address: request.remote_ip,
  # Additional context-specific metadata
}
```

### User Flows

#### Constituent Portal Upload
1. Constituent logs into the portal
2. Navigates to their application
3. Selects document(s) to upload
4. The system validates and processes the uploads
5. Constituent receives confirmation of successful upload
6. Document statuses are updated to "not_reviewed"
7. Administrators are notified of pending documents for review

#### Admin Paper Application Upload
1. Administrator creates a new paper application
2. Enters constituent information
3. Uploads scanned proof documents
4. The system validates and processes the uploads
5. Documents can be automatically approved during upload
6. Audit records are created for all uploads

#### Proof Resubmission
1. A constituent submits an application with proof documents
2. An administrator reviews and may reject one or both proofs
3. When a proof is rejected, the constituent receives a notification
4. The constituent logs into the constituent portal and sees their rejected proof(s)
5. The constituent clicks the "Upload New Proof" button for the rejected proof
6. The constituent selects a new file and submits it
7. The new proof is sent to administrators for review

### Technical Implementation

#### ProofAttachmentService
The central service for all file operations:

```ruby
def self.attach_proof(application:, proof_type:, blob_or_file:, status:, admin: nil, metadata: {})
  # Ensure we have the required metadata
  metadata[:submission_method] ||= admin ? :paper : :web
  
  # Wrapped in a transaction for data integrity
  ActiveRecord::Base.transaction do
    # Attach the file to the application
    if proof_type.to_s == 'income'
      application.income_proof.attach(blob_or_file)
    elsif proof_type.to_s == 'residency'
      application.residency_proof.attach(blob_or_file)
    end
    
    # Update application status
    application.update!(
      "#{proof_type}_proof_status" => status,
      "#{proof_type}_proof_submitted_at" => Time.current,
      "#{proof_type}_proof_admin_id" => admin&.id
    )
    
    # Create audit record
    ProofSubmissionAudit.create!(
      application: application,
      user: admin || application.user,
      proof_type: proof_type,
      submission_method: metadata[:submission_method],
      ip_address: metadata[:ip_address] || '0.0.0.0',
      success: true,
      metadata: metadata
    )
    
    { success: true }
  end
rescue => error
  record_failure(application, proof_type, error, admin, metadata)
  { success: false, error: error.message }
end
```

#### Policy Enforcement
- **Resubmission Limits**: Constituents are limited in how many times they can resubmit a proof
- **File Validation**: File size limits and allowed file types are enforced
- **Rate Limiting**: Submissions are rate-limited to prevent abuse

#### Monitoring and Metrics
- The `ProofAttachmentMetricsJob` analyzes audit data and generates metrics
- When failure rates exceed 5% with more than 5 failures in the past 24 hours, administrators are automatically notified
- Comprehensive audit trail through `ProofSubmissionAudit` model

---

## Email Tracking

The email tracking system provides detailed tracking of email delivery status, particularly for medical certification requests.

### Implementation

#### Database Schema
Email tracking information is stored in the `notifications` table:
- `message_id`: Unique Postmark message ID for tracking
- `delivery_status`: Current status (e.g., "Delivered", "Opened", "error")
- `delivered_at`: When the email was successfully delivered
- `opened_at`: When the email was first opened
- `metadata`: JSON column storing additional information like browser and location

#### Service Layer
The `Applications::MedicalCertificationService` handles email tracking by:
- Creating notifications with tracking metadata
- Scheduling `MedicalCertificationEmailJob` with notification_id parameter
- The `PostmarkEmailTracker` service fetches delivery status from Postmark API
- `UpdateEmailStatusJob` processes status updates with retry logic

```ruby
def request_certification
  notification = create_notification(current_time)
  send_email(notification)
end
```

#### Email Job
The `MedicalCertificationEmailJob` accepts a notification ID parameter for tracking:

```ruby
MedicalCertificationEmailJob.perform_later(
  application_id: application.id, 
  timestamp: timestamp.iso8601,
  notification_id: notification&.id
)
```

#### Mailer Integration
The mailer records the Postmark message ID when the email is sent, enabling tracking of delivery and open events through the Postmark API.

#### Status Updates
- `UpdateEmailStatusJob` queries Postmark API for delivery status
- Updates notification records with delivery_status, delivered_at, opened_at
- Stores detailed open information (client, location) in metadata
- Schedules follow-up checks for unopened emails

### UI Components
The certification history modal displays:
- Delivery status badges with color coding
- Timestamps for delivery and opens
- Device and location information for opened emails
- Manual "Check Status" buttons for pending deliveries

### Postmark Configuration Requirements
For email tracking to work correctly:

1. **API Token**: Set the `POSTMARK_API_TOKEN` environment variable
2. **Open Tracking**: Ensure open tracking is enabled in Postmark account settings
3. **Message Streams**: Configure appropriate streams (outbound, notifications)
4. **Webhook Setup** (Optional): Configure Postmark webhooks for real-time updates

### Handling Duplicate Notifications
The system includes duplicate detection logic and provides rake tasks for fixing duplicates:

```bash
# Analyze discrepancies without making changes
rails notification_tracking:analyze[APPLICATION_ID]

# Fix duplicate notifications
rails notification_tracking:fix_duplicates[APPLICATION_ID]

# Check status of all tracked emails
rails notification_tracking:check_all
```

### Integration With Other Email Types
To add tracking to other types of emails:
1. Create a notification record with appropriate metadata
2. Pass the notification to the mailer
3. Update the mailer to capture the message ID
4. Schedule the `UpdateEmailStatusJob` to check the delivery status

---

## Guardian Relationship System

The guardian relationship system allows adult users to manage applications for dependents (such as minors or adults who need assistance). This system provides a comprehensive framework for handling applications submitted by guardians on behalf of their dependents.

### Process Overview

1. A guardian user creates a dependent user account through the constituent portal
2. A `GuardianRelationship` is established linking the guardian to the dependent
3. The guardian can create and manage applications for their dependents
4. Applications are tracked with both the dependent as the applicant and the guardian as the managing party
5. Administrators can view and manage these relationships through the admin interface

### Key Components

#### Models
- **GuardianRelationship**: Links guardian users to dependent users with relationship type
- **Application**: Enhanced with `managing_guardian_id` to track who manages the application
- **User**: Extended with guardian/dependent associations and helper methods

#### Guardian/Dependent Associations
```ruby
# Guardian associations
has_many :guardian_relationships_as_guardian
has_many :dependents, through: :guardian_relationships_as_guardian
has_many :managed_applications, foreign_key: 'managing_guardian_id'

# Dependent associations  
has_many :guardian_relationships_as_dependent
has_many :guardians, through: :guardian_relationships_as_dependent
```

#### Dependent Contact Information Management
The system supports flexible contact information handling for dependents:

```ruby
# Dependent-specific contact fields (encrypted)
dependent_email    # Optional email specific to dependent
dependent_phone    # Optional phone specific to dependent

# Helper methods for effective contact information
def effective_email
  return dependent_email if dependent_email.present?
  email  # Falls back to primary email (often system-generated for shared contacts)
end

def effective_phone  
  return dependent_phone if dependent_phone.present?
  phone  # Falls back to primary phone (often system-generated for shared contacts)
end

# Contact info strategy helpers
def has_own_contact_info?
  dependent_email.present? || dependent_phone.present?
end

def uses_guardian_contact_info?
  !has_own_contact_info?
end
```

**Key Benefits:**
- No database uniqueness constraint violations when dependents share guardian contact info
- Clear separation between system-required unique fields and actual communication preferences
- Flexible support for dependents who have their own contact info vs. those who share guardian's
- Maintains data integrity while supporting real-world family contact scenarios

#### Application Scopes
- `managed_by(guardian_user)`: Applications managed by a specific guardian
- `for_dependents_of(guardian_user)`: Applications for dependents of a guardian
- `related_to_guardian(guardian_user)`: All applications related to a guardian

### User Workflows

#### Constituent Portal - Guardian Management
1. **Adding Dependents**: Guardians can add dependents via `/constituent_portal/dependents/new`
2. **Managing Applications**: Guardians can create applications for their dependents
3. **Dashboard View**: Shows both personal applications and dependent applications
4. **Application Selection**: When creating applications, guardians choose between self or dependent

#### Admin Portal - Relationship Management
1. **Viewing Relationships**: Admin user pages show guardian/dependent relationships
2. **Creating Relationships**: Admins can establish new guardian relationships
3. **Paper Applications**: Support for creating applications with guardian/dependent context
4. **Filtering**: Applications can be filtered by guardian or dependent relationships

### Technical Implementation

#### Relationship Validation
- Unique constraint on guardian_id + dependent_id pairs
- Relationship type is required (Parent, Legal Guardian, etc.)
- Prevents circular relationships and self-relationships

#### Application Context
```ruby
# Check if application is for a dependent
application.for_dependent?  # Returns true if managing_guardian_id present

# Get relationship type
application.guardian_relationship_type  # Returns relationship type from GuardianRelationship

# Automatic guardian assignment
application.ensure_managing_guardian_set  # Callback to set managing_guardian_id
```

#### Audit Trail
- `ApplicationStatusChange` records include guardian context
- `Event` records track guardian-related actions
- Profile changes for dependents are logged with guardian information

### Security and Validation

#### Access Control
- Guardians can only manage their established dependents
- Dependent users cannot access guardian functionality
- Admin verification required for relationship establishment

#### Data Integrity
- Guardian relationships are destroyed when users are deleted
- Applications maintain referential integrity with nullify on guardian deletion
- Validation prevents duplicate relationships

### UI Features

#### Dashboard Enhancements
- Separate sections for personal vs dependent applications
- Clear indication of guardian/dependent status
- Contextual action buttons based on relationship

#### Application Forms
- Guardian selection dropdown when creating applications
- Clear labeling of who the application is for
- Relationship type display in application details

#### Admin Interface
- Guardian/dependent relationship management
- Bulk operations for related applications
- Enhanced filtering and search capabilities

---

## Cross-Feature Integration

These features work together to provide a comprehensive application management system:

- **Medical certifications** can be submitted via the **proof attachment system** through email
- **Email tracking** monitors the delivery of medical certification requests
- **Guardian relationships** enable complex application workflows where guardians manage dependent applications
- **Dependent contact handling** uses flexible contact strategies (email_strategy, phone_strategy, address_strategy) allowing dependents to either have their own contact information or share their guardian's without database conflicts
- **Paper application system** supports unified parameter handling with clean contact strategy logic
- **Proof attachment system** handles documents for both self-applications and guardian-managed applications
- All systems use consistent **audit trails** and **error handling** patterns
- **Policy enforcement** applies across all document submission methods
- **Guardian context** is preserved throughout the application lifecycle and audit processes
- **Contact information flexibility** supports real-world family scenarios while maintaining data integrity

## Troubleshooting

### Common Issues
1. **File Upload Failures**: Check S3 connectivity, file validation, and transaction issues
2. **Email Tracking Issues**: Verify Postmark configuration and API tokens
3. **Medical Certification Workflow**: Ensure proper provider information and notification creation

### Debugging Tools
- Check application logs for detailed error messages
- Review audit records in `ProofSubmissionAudit` and `notifications` tables
- Use the admin interface to monitor system status and pending items
- Utilize rake tasks for data analysis and cleanup

## Future Improvements

### High Priority
- Enhanced file validations with virus scanning
- Direct-to-S3 uploads with signed URLs
- Improved mobile support for document uploads

### Medium Priority
- Provider portal for medical providers
- Auto-reminders for pending certifications
- Batch processing for administrators

### Lower Priority
- Document AI for automated validation
- Digital signatures for certifications
- Advanced analytics and reporting
