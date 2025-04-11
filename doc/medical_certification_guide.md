# Medical Certification System

## Table of Contents
1. [Introduction](#introduction)
2. [Process Overview](#process-overview)
3. [Key Components](#key-components)
4. [Administrator Workflows](#administrator-workflows)
   - [Requesting Certifications](#requesting-certifications)
   - [Uploading and Approving Certifications](#uploading-and-approving-certifications)
   - [Rejecting Certifications](#rejecting-certifications)
5. [Constituent Experience](#constituent-experience)
6. [Technical Implementation](#technical-implementation)
7. [Troubleshooting](#troubleshooting)
8. [Future Improvements](#future-improvements)

## Introduction

The medical certification system allows constituents to request certification of their disability from a medical provider. This certification is a critical part of the application process, as it confirms the constituent's eligibility for services. This document provides a comprehensive overview of the medical certification process, including the administrative workflows, technical implementation, and user experience.

## Process Overview

The medical certification process follows these general steps:

1. A constituent applies for services and indicates they need a medical certification
2. An administrator sends a certification request to the constituent's medical provider
3. The medical provider completes the certification and returns it (via fax, email, mail, etc.)
4. An administrator uploads and approves the certification
5. The application progresses to the next step in the approval process

## Key Components

### Models

- **Application**: Stores medical certification status, request count, and timestamps
- **Notification**: Tracks history of certification requests with metadata
- **MedicalProvider**: Contains provider contact information

### Services

- **MedicalCertificationService**: Handles the business logic for certification requests
  - Validates prerequisites
  - Updates application status
  - Creates notifications
  - Handles error cases gracefully

- **MedicalCertificationAttachmentService**: Processes certification document uploads
  - Manages file attachments
  - Updates certification status
  - Creates audit records

- **MedicalCertificationReviewer**: Handles the review process
  - Validates certification documents
  - Updates application status based on review outcome
  - Notifies relevant parties

### Jobs

- **MedicalCertificationEmailJob**: Background job for email delivery
  - Ensures reliable email delivery
  - Provides retry capability for transient failures
  - Decouples request processing from email delivery

### Controllers

- **Admin::ApplicationsController**: Provides interface for admins to request, upload, and approve certifications
- **ConstituentPortal::ApplicationsController**: Shows certification status to constituents

### Views

- **Admin view**: Shows detailed certification history with timestamps and upload/approval interface
- **Constituent view**: Displays certification status, provider info, and request history

## Administrator Workflows

### Requesting Certifications

Administrators can request a medical certification by:

1. Navigating to the application details page
2. Verifying the medical provider information is correct
3. Clicking the "Request Medical Certification" button
4. Confirming the action

This creates a notification and sends an email to the medical provider with instructions for completing and returning the certification.

### Uploading and Approving Certifications

When a medical certification is received (via fax, email, mail, etc.), administrators can upload and approve it in a single step:

1. Navigate to the application details page
2. Locate the "Upload Faxed Medical Certification" section
3. Select "Approve Certification and Upload"
4. Use the file picker to select the scanned certification document
5. Click "Process Certification"

This streamlined process:
- Attaches the certification document to the application
- Sets the certification status to "Approved"
- Creates an audit log entry
- Makes the document visible in the certification history

### Rejecting Certifications

If a received certification is incomplete or invalid, administrators can reject it:

1. Navigate to the application details page
2. Locate the "Upload Faxed Medical Certification" section
3. Select "Reject Certification"
4. Select a common rejection reason or enter a custom reason
5. Add additional notes if needed to help the provider understand what to correct
6. Click "Process Certification"

This process:
- Does not attach any document to the application
- Sets the certification status to "Rejected"
- Notifies the provider of the rejection reason
- Creates an audit log entry
- Records the rejection in the certification history

## Constituent Experience

Constituents can view the status of their medical certification in the constituent portal. They will see:

- Current certification status (requested, approved, rejected)
- Medical provider information
- History of certification requests
- Dates when requests were sent

If a certification is rejected, constituents will be notified and can see the reason for rejection in the portal.

## Technical Implementation

### Certification Status Tracking

The application model includes fields for tracking certification status:

```ruby
class Application < ApplicationRecord
  enum medical_certification_status: {
    not_required: 0,
    requested: 1,
    accepted: 2,
    approved: 3,
    rejected: 4
  }
  
  # Additional fields
  # - medical_certification_requested_at: datetime
  # - medical_certification_request_count: integer
  # - medical_certification_completed_at: datetime
end
```

### Request History Tracking

We use a notification-based approach to track the history of certification requests:

1. Each request creates a notification with metadata including timestamp and request number
2. Views query the notification table to display the history
3. This provides a reliable audit trail of all requests

### Direct Approval Process

The certification upload and approval process has been streamlined into a single step:

```ruby
result = MedicalCertificationAttachmentService.attach_certification(
  application: @application,
  blob_or_file: params[:medical_certification],
  status: :approved,  # Sets the status directly to "approved"
  admin: current_admin,
  metadata: { submission_method: :upload }
)
```

### Background Processing

Email delivery is handled in a background job to:

1. Improve request handling performance
2. Allow for retries of failed deliveries
3. Prevent email failures from affecting the user experience

## Troubleshooting

### Common Issues

- **Certification Upload Error**: Check that the file is a supported format (PDF, JPG, PNG) and under the maximum size limit
- **Rejection Button Issues**: If the rejection buttons don't populate the reason field, try clicking a different button or typing your reason manually
- **Missing Upload Form**: Check that the certification status is "Requested" and no document is already attached

### Debugging Tips

1. Check the application logs for detailed error messages
2. Review the notification records for the application to see the history of actions
3. Verify that the medical provider information is correct and complete
4. Ensure the file being uploaded meets the system requirements

## Future Improvements

Potential enhancements to consider:

1. **Email templating**: Allow customization of certification request emails
2. **Provider portal**: Create a dedicated portal for medical providers to submit certifications
3. **Auto-reminders**: Automatically send follow-up requests after a defined period
4. **Status webhooks**: Integrate with external systems to update certification status
5. **Digital signatures**: Add support for electronically signed certifications
6. **Bulk operations**: Enable processing multiple certifications at once
