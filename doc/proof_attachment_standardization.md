# Proof Attachment Standardization

## Overview

This document describes the recent standardization of proof attachment flows between the constituent portal and admin paper application processes. The standardization effort addressed several issues and inconsistencies between these two workflows, creating a more maintainable and reliable system.

## Key Standardization Changes

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

## Implementation Details

### Constituent Portal Changes

The constituent portal's `upload_documents` method was refactored from:

```ruby
def upload_documents
  @application = current_user.applications.find(params[:id])
  if params[:documents].present?
    params[:documents].each do |document_type, file|
      case document_type
      when "income_proof"
        @application.income_proof.attach(file)
      when "residency_proof"
        @application.residency_proof.attach(file)
      end
    end

    if @application.save
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

To a more robust implementation that uses the central service and transaction safety:

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
          # Use the shared ProofAttachmentService for consistency with paper applications
          result = ProofAttachmentService.attach_proof(
            application: @application,
            proof_type: :income,
            blob_or_file: file,
            status: :not_reviewed, # Default status for constituent uploads
            admin: nil, # No admin for constituent uploads
            metadata: { 
              submission_method: :web,
              ip_address: request.remote_ip
            }
          )
          return false unless result[:success]
          processed_proofs << "income"
          
        when "residency_proof"
          # Similar implementation for residency proof...
        end
      end
      
      # More processing as needed...
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

### Paper Application Service Changes

The `PaperApplicationService` was updated to ensure robust error handling, particularly for the `submission_method` field:

```ruby
def process_proof(type)
  # ...

  if action == 'accept'
    # Use ProofAttachmentService for file upload
    result = ProofAttachmentService.attach_proof(
      application: @application,
      proof_type: type,
      blob_or_file: params["#{type}_proof"],
      status: :approved,
      admin: @admin,
      metadata: { submission_method: :paper } # This is used in both success and failure paths
    )
    
    # Rest of the implementation...
  end

  # ...
end
```

### ProofAttachmentService Changes

The service was updated to properly handle the `submission_method` in all paths, including error handling:

```ruby
def self.record_failure(application, proof_type, error, admin, metadata)
  # ...
  
  # Extract submission method from metadata or infer from admin presence
  submission_method = metadata[:submission_method] || (admin ? :paper : :web)
  
  # Record the failure for metrics and monitoring
  ProofSubmissionAudit.create!(
    application: application,
    user: admin || application.user,
    proof_type: proof_type,
    submission_method: submission_method,  # Now properly set in all paths
    ip_address: metadata[:ip_address] || '0.0.0.0',
    metadata: metadata.merge(
      success: false,
      error_class: error.class.name,
      error_message: error.message,
      error_backtrace: error.backtrace.first(5)
    )
  ) rescue nil
  
  # ...
end
```

### Model Validation

Added explicit validation for `submission_method` in the `ProofSubmissionAudit` model:

```ruby
class ProofSubmissionAudit < ApplicationRecord
  # ...
  validates :proof_type, presence: true
  validates :ip_address, presence: true
  validates :submission_method, presence: true  # New validation
  # ...
end
```

## Benefits of Standardization

1. **Improved Reliability**: Both flows handle errors consistently and maintain data integrity through transactions
2. **Better Debugging**: Standard metadata and audit records make it easier to identify and fix issues
3. **Centralized Code**: Changes to attachment logic only need to be made in one place
4. **Consistent Metrics**: Monitoring can now compare apples-to-apples between the two submission paths
5. **Reduced Code Duplication**: Shared logic results in less code to maintain and test

## Future Improvements

- Further standardize the UI components between the two flows
- Consider implementing client-side validation for files before upload
- Implement direct-to-S3 uploads with progress indicators
- Expand validation to include file type and size checks
- Implement virus scanning integration

## Related Documentation

- [Proof Attachment Improvements](proof_attachment_improvements.md): Detailed improvement recommendations
- [Proof Attachment Monitoring](proof_attachment_monitoring.md): How attachment success/failure is monitored
- [Paper Application Upload Refactor](paper_application_upload_refactor.md): Historical document about an earlier refactoring
- [Paper Application Attachment Fix](paper_application_attachment_fix.md): Historical document about an earlier fix
