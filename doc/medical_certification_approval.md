# Medical Certification Approval Process

This document describes how administrators can approve or reject medical certifications received via fax in the MAT Vulcan system.

## Overview

When medical certification documents are received via fax, administrators need to scan these documents and upload them to the system. During this process, they can:

1. **Approve** the certification and attach the scanned document
2. **Reject** the certification with a specific reason, notifying the medical provider

## Features

### Upload Form

The medical certification upload form allows administrators to:

- Choose whether to approve or reject a certification
- Upload scanned certification documents (for approval)
- Select a rejection reason and provide notes (for rejection)

### Approval Process

When approving a certification:

1. Administrator selects "Accept Certification and Upload"
2. Administrator uploads the scanned document
3. System updates the medical certification status to "approved"
4. System creates an audit log entry for the approval

### Rejection Process

When rejecting a certification:

1. Administrator selects "Reject Certification"
2. Administrator selects a rejection reason from the dropdown
3. Administrator provides detailed notes explaining the rejection reason
4. System updates the medical certification status to "rejected"
5. System automatically notifies the medical provider about the rejection

## Technical Implementation

The implementation leverages existing patterns in the application:

- Uses the `proof_status_controller.js` Stimulus controller to toggle form sections
- Shares code with the paper application upload mechanism
- Leverages the `Applications::MedicalCertificationReviewer` service for rejections
- Creates appropriate audit logs and notifications

## User Flow

1. Admin navigates to an application with requested medical certification
2. Admin clicks either "Accept Certification and Upload" or "Reject Certification"
3. Admin completes the appropriate form section
4. Admin clicks "Process Certification"
5. System processes the request and displays a success/error message
6. Admin can view the certification status in the application history

## Rejection Reasons

The system supports the following rejection reasons:

- Invalid Signature
- Missing Information
- Expired Documentation
- Wrong Document Type
- Illegible Document
- Incomplete Form
- Other

## Future Enhancements

Potential future enhancements could include:

- Direct integration with fax services to automatically receive and process certifications
- OCR processing to automatically extract data from certification documents
- Automated validation checks for certification documents
