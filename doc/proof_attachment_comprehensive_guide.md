# Proof Attachment Comprehensive Guide

This document provides a complete overview of the proof attachment system used in the MAT Vulcan application, including its current implementation, monitoring, and future roadmap.

## Table of Contents
1. [Introduction](#introduction)
2. [Standardization Implementation](#standardization-implementation)
3. [Current Architecture](#current-architecture)
4. [Monitoring System](#monitoring-system)
5. [Debugging Guidelines](#debugging-guidelines)
6. [Future Improvements](#future-improvements)
7. [Related Historical Documents](#related-historical-documents)

## Introduction

The proof attachment system handles document uploads for residency and income verification in the application. Documents can be submitted through two main channels:
- The constituent portal (self-service)
- The admin interface (paper applications)

This document describes the current state of the system and future roadmap.

## Standardization Implementation

To address the inconsistent approaches, we implemented a standardized architecture with the following key changes:

### 1. Unified Service Approach

- Both constituent portal and admin paper applications now use the `ProofAttachmentService` for all document attachments
- This replaces the previous approach where constituent portal used direct ActiveStorage attachments
- Provides consistent error handling, audit trails, and metrics for all file operations

### 2. Consistent Transaction Safety

- Both flows now use `ActiveRecord::Base.transaction` for data integrity
- All operations (file attachment, status updates, and audit records) are wrapped in transactions
- Ensures no partial updates occur that could leave the system in an inconsistent state

### 3. Standardized Metadata

- Both flows now pass similar metadata to the attachment service:
```ruby
metadata: { 
  submission_method: :web, # or :paper for admin uploads
  ip_address: request.remote_ip
}
```
- This provides consistent context for monitoring, debugging, and metrics

### 4. Robust Error Handling

- The service detects errors in both file processing and database operations
- All errors are consistently tracked in the `ProofSubmissionAudit` model
- Added `submission_method` validation in the model to catch issues earlier

### 5. Improved Submission Method Handling

- Fixed issues with `submission_method` not being properly set in error cases
- Added validation to the `ProofSubmissionAudit` model
- Implemented fallback logic to determine submission method from context

## Current Architecture

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

### Controller Implementation

The constituent portal's `upload_documents` method was standardized to use the service:

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

### ProofSubmissionAudit Model

A critical part of the system that provides audit trails and enables monitoring:

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

## Monitoring System

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

### Testing

The monitoring system is tested through:
1. Unit tests for the ProofAttachmentService
2. Integration tests for attachment operations
3. Job tests that verify metrics calculation and notification thresholds

## Debugging Guidelines

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

## Common Failure Types

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

## Related Historical Documents

For historical context, these documents describe earlier stages of the system:
- [Paper Application Upload Refactor](paper_application_upload_refactor.md)
- [Paper Application Attachment Fix](paper_application_attachment_fix.md)
