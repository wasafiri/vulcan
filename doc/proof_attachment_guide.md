# Proof Attachment System

## Table of Contents
1. [Introduction](#introduction)
2. [System Architecture](#system-architecture)
3. [User Flows](#user-flows)
   - [Constituent Portal Upload](#constituent-portal-upload)
   - [Admin Paper Application Upload](#admin-paper-application-upload)
   - [Proof Resubmission](#proof-resubmission)
4. [Technical Implementation](#technical-implementation)
   - [ProofAttachmentService](#proofattachmentservice)
   - [Controllers](#controllers)
   - [Model Implementation](#model-implementation)
5. [Policy Enforcement](#policy-enforcement)
6. [Monitoring and Metrics](#monitoring-and-metrics)
7. [Debugging and Troubleshooting](#debugging-and-troubleshooting)
8. [Future Improvements](#future-improvements)

## Introduction

The proof attachment system handles document uploads for residency and income verification in the MAT Vulcan application. Documents can be submitted through multiple channels:

- The constituent portal (self-service)
- The admin interface (paper applications)
- Email submissions (via Action Mailbox)
- Faxed documents

This guide provides a comprehensive overview of how the proof attachment system works, its architecture, monitoring, troubleshooting, and future roadmap.

## System Architecture

The proof attachment system is built around a standardized architecture with the following key components:

### 1. Unified Service Approach

- All document attachments use the `ProofAttachmentService` regardless of submission method
- Provides consistent error handling, audit trails, and metrics for all file operations
- Centralizes file validation, attachment logic, and status updates

### 2. Consistent Transaction Safety

- All operations use `ActiveRecord::Base.transaction` for data integrity
- File attachment, status updates, and audit records are wrapped in transactions
- Ensures no partial updates occur that could leave the system in an inconsistent state

### 3. Standardized Metadata

All attachment operations include metadata:
```ruby
metadata: { 
  submission_method: :web, # or :paper, :email, :fax, etc.
  ip_address: request.remote_ip,
  # Additional context-specific metadata
}
```

### 4. Audit Trail

- All attachment operations (successful or failed) are recorded in `ProofSubmissionAudit`
- Enables monitoring, debugging, and reporting on submission activities
- Tracks metadata for each operation to provide context

### 5. Error Handling

- Robust error capture and reporting across all submission paths
- Graceful handling of common failure scenarios
- Clear error messaging for both users and administrators

## User Flows

### Constituent Portal Upload

1. Constituent logs into the portal
2. Navigates to their application
3. Selects document(s) to upload
4. The system validates and processes the uploads
5. Constituent receives confirmation of successful upload
6. Document statuses are updated to "not_reviewed"
7. Administrators are notified of pending documents for review

### Admin Paper Application Upload

1. Administrator creates a new paper application
2. Enters constituent information
3. Uploads scanned proof documents
4. The system validates and processes the uploads
5. Documents can be automatically approved during upload
6. Audit records are created for all uploads

### Proof Resubmission

1. A constituent submits an application with proof documents
2. An administrator reviews and may reject one or both proofs
3. When a proof is rejected, the constituent receives a notification
4. The constituent logs into the constituent portal and sees their rejected proof(s)
5. The constituent clicks the "Upload New Proof" button for the rejected proof
6. The constituent selects a new file and submits it
7. The new proof is sent to administrators for review

## Technical Implementation

### ProofAttachmentService

The central service for all file operations:

```ruby
def self.attach_proof(application:, proof_type:, blob_or_file:, status:, admin: nil, metadata: {})
  # Ensure we have the required metadata
  metadata[:submission_method] ||= admin ? :paper : :web
  
  # Validate parameters
  unless application && proof_type && blob_or_file
    record_failure(
      application, 
      proof_type, 
      ArgumentError.new("Missing required parameters"), 
      admin, 
      metadata
    )
    return { success: false, error: "Missing required parameters" }
  end
  
  # Wrapped in a transaction for data integrity
  ActiveRecord::Base.transaction do
    # Attach the file to the application
    if proof_type.to_s == 'income'
      application.income_proof.attach(blob_or_file)
    elsif proof_type.to_s == 'residency'
      application.residency_proof.attach(blob_or_file)
    else
      raise ArgumentError, "Invalid proof type: #{proof_type}"
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
    
    # Return success
    { success: true }
  end
rescue => error
  # Record failure details
  record_failure(application, proof_type, error, admin, metadata)
  { success: false, error: error.message }
end
```

### Controllers

The constituent portal's `upload_documents` method:

```ruby
def upload_documents
  @application = current_user.applications.find(params[:id])
  if params[:documents].present?
    success = ActiveRecord::Base.transaction do
      # Track which proofs were processed for better user feedback
      processed_proofs = []
      
      params[:documents].each do |document_type, file|
        case document_type
        when "income_proof"
          # Use the shared ProofAttachmentService
          result = ProofAttachmentService.attach_proof(
            application: @application,
            proof_type: :income,
            blob_or_file: file,
            status: :not_reviewed,
            admin: nil,
            metadata: { 
              submission_method: :web,
              ip_address: request.remote_ip
            }
          )
          return false unless result[:success]
          processed_proofs << "income"
        when "residency_proof"
          # Similar implementation for residency proof
        end
      end
      
      true # Return true to indicate successful transaction
    end

    if success
      redirect_to constituent_portal_application_path(@application),
                  notice: "Documents uploaded successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  else
    redirect_to constituent_portal_application_path(@application),
                alert: "Please select documents to upload."
  end
end
```

### Model Implementation

The `ProofSubmissionAudit` model provides audit trails:

```ruby
class ProofSubmissionAudit < ApplicationRecord
  belongs_to :application
  belongs_to :user, optional: true
  
  enum proof_type: { income: 0, residency: 1 }
  enum submission_method: { web: 0, paper: 1, email: 2, mail: 3, fax: 4 }
  
  validates :proof_type, presence: true
  validates :ip_address, presence: true
  validates :submission_method, presence: true
  
  # Store additional metadata as JSON
  store :metadata, coder: JSON
  
  # Scopes for monitoring
  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
  
  # Time-based scopes
  scope :recent, -> { where('created_at > ?', 24.hours.ago) }
  scope :last_week, -> { where('created_at > ?', 1.week.ago) }
end
```

The `ProofManageable` concern provides proof-related functionality to the `Application` model:

```ruby
module ProofManageable
  extend ActiveSupport::Concern
  
  # Constants for validation
  MAX_FILE_SIZE = 10.megabytes
  ALLOWED_TYPES = %w[image/jpeg image/png application/pdf]

  included do
    # Active Storage attachments
    has_one_attached :income_proof
    has_one_attached :residency_proof
    
    # Callbacks
    after_commit :create_proof_submission_audit, on: [:create, :update]
    before_save :set_proof_status_to_unreviewed, if: :proof_attachments_changed?
    
    # Enums for proof statuses
    enum income_proof_status: { not_reviewed: 0, approved: 1, rejected: 2 }
    enum residency_proof_status: { not_reviewed: 0, approved: 1, rejected: 2 }
    
    # Validations
    validate :validate_proof_file_types
    validate :validate_proof_file_sizes
  end
  
  # Methods related to proofs
  def can_resubmit_proof?(proof_type)
    return false unless send("#{proof_type}_proof_status") == "rejected"
    
    # Get submission count
    submission_count = proof_submission_audits
                        .where(proof_type: proof_type)
                        .count
    
    # Check against policy limit
    max_submissions = Policy.get('max_proof_submissions') || 3
    submission_count < max_submissions
  end
  
  private
  
  def proof_attachments_changed?
    income_proof.changed? || residency_proof.changed?
  end
  
  def set_proof_status_to_unreviewed
    if income_proof.changed?
      self.income_proof_status = :not_reviewed
    end
    
    if residency_proof.changed?
      self.residency_proof_status = :not_reviewed
    end
  end
  
  def validate_proof_file_types
    # Validation implementation
  end
  
  def validate_proof_file_sizes
    # Validation implementation
  end
end
```

## Policy Enforcement

The system enforces several policies:

### 1. Resubmission Limits

Constituents are limited in how many times they can resubmit a proof. This limit is defined in the `Policy` model with the `max_proof_submissions` setting. When a constituent reaches this limit, they will no longer see the "Upload New Proof" button and must contact support.

### 2. File Validation

- File size limits defined in `ProofManageable::MAX_FILE_SIZE`
- Allowed file types defined in `ProofManageable::ALLOWED_TYPES`
- Validation occurs both in the client and server

### 3. Rate Limiting

- Submissions are rate-limited to prevent abuse
- The `RateLimit` service controls submission frequency

## Monitoring and Metrics

The proof attachment monitoring system tracks all submissions through the `ProofSubmissionAudit` model and analyzes the data to identify potential issues.

### Components

1. **ProofAttachmentService Telemetry**
   - Records comprehensive metadata about each attempt
   - Handles error cases gracefully
   - Creates audit records for each operation
   - Records timing information for performance monitoring

2. **ProofSubmissionAudit Model**
   - Stores detailed information about each proof submission attempt
   - Enables filtering and aggregation for metrics

3. **Daily Metrics Job**
   - The `ProofAttachmentMetricsJob` analyzes audit data and generates metrics:
     - Overall success/failure rates
     - Success/failure rates by proof type
     - Success/failure rates by submission method (web vs. paper)
   - When failure rates exceed 5% with more than 5 failures in the past 24 hours, administrators are automatically notified

### Schedule Configuration

The metrics job is scheduled via `config/recurring.yml`:

```yaml
proof_attachment_metrics:
  class: ProofAttachmentMetricsJob
  cron: "0 0 * * *"  # At midnight every day
  description: "Generate daily metrics on proof attachment success/failure rates"
  queue: "low"
```

## Debugging and Troubleshooting

### Common Issues and Solutions

#### Status Not Updating

If proof status isn't updating correctly:
1. Check `ProofManageable` concern for the `set_proof_status_to_unreviewed` method
2. Verify that callbacks are firing on attachment changes

#### Missing Upload Button

If the upload button doesn't appear for rejected proofs:
1. Confirm proof status is correctly set to `rejected`
2. Check that `can_resubmit_proof?` logic in the dashboard controller is working
3. Verify the user hasn't exceeded maximum resubmission attempts

#### Audit Records Missing

If audit records are missing:
1. Check `create_proof_submission_audit` in the `ProofManageable` concern
2. Verify the `ProofSubmissionAudit` model is working correctly

### Checking Logs

When investigating attachment failures:

1. **Check Application Logs**
   - Look for detailed error messages
   - Pay attention to ActiveStorage errors

2. **Review ProofSubmissionAudit Records**
   - Query for failed submissions:
     ```ruby
     ProofSubmissionAudit.failed.where(application_id: application.id)
     ```
   - Check the `metadata` field for error details

3. **Look for Patterns**
   - Common error types
   - Specific IP addresses
   - Browser patterns

4. **Verify S3 Connectivity**
   - Check AWS service status
   - Verify IAM permissions
   - Check network connectivity

### Common Failure Types

Some common reasons for attachment failures:

1. **S3 connectivity issues**
   - Check network connectivity
   - Check S3 service status
   - Verify AWS credentials

2. **File validation failures**
   - File size exceeds limits
   - Unsupported file type
   - Corrupted files

3. **Database transaction issues**
   - Transaction nesting problems
   - Database locks or contention
   - Timeout issues

4. **Permission errors**
   - Verify proper IAM permissions for S3 bucket
   - Check application permission configuration

## Future Improvements

Several opportunities for further enhancement remain:

### High Priority
1. **File Validations**
   - Implement client-side validations for immediate feedback
   - Add server-side validation for security
   - Integrate with virus scanning services
   - Set size limits based on S3 configuration

2. **Audit Trail Enhancements**
   - Standardize audit trail information regardless of submission path
   - Store all context information for both submission and later reviews
   - Implement a comprehensive audit log view for administrators

### Medium Priority
1. **Performance Improvements**
   - Implement direct-to-S3 uploads with signed URLs
   - Use background jobs for post-upload processing
   - Add progress indicators for users

2. **Retry Mechanisms**
   - Add exponential backoff retry logic for transient failures
   - Provide clear feedback to users during retries
   - Implement a circuit breaker pattern for persistent failures

### Lower Priority
1. **UI Standardization**
   - Further standardize the UI components between the two flows
   - Improve error messaging to end users
   - Add visual indicators for attachment states

2. **Testing Coverage**
   - Add comprehensive tests for constituent portal uploads
   - Implement integration tests that cover the full attachment flow
   - Add specific tests for error conditions and edge cases

## Future Considerations

- **Mobile Support**: Optimize the attachment process for mobile devices
- **Multiple File Handling**: Support attaching multiple proofs at once
- **Document AI**: Implement automated proof validation using machine learning
- **Batch Processing**: Support for administrators to process multiple proofs efficiently
