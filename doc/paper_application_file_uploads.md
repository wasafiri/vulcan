# Paper Application File Upload Guide

This document explains how file uploads work for paper applications, focusing on S3 integration and direct uploads.

## Overview

Paper applications allow admins to upload proof documents (income and residency) when submitting applications. We use ActiveStorage with direct uploads to ensure consistent behavior between development (local storage) and production (S3 storage).

## How Direct Upload Works

### Client-Side Flow

1. When an admin selects a file in the paper application form, the `upload_controller.js` handles the file:
   - Captures the selected file
   - Shows a progress bar
   - Uploads directly to the storage provider (S3 in production, local disk in development)
   - Receives a `signed_id` from the server
   - Stores the `signed_id` in a hidden field that gets submitted with the form

2. The full form submission includes these `signed_id` values instead of the actual files

### Server-Side Flow

1. The `PaperApplicationsController` provides a `direct_upload` endpoint:
   - Creates blob records with ActiveStorage
   - Returns signed URLs for direct upload to S3

2. When the application form is submitted:
   - `PaperApplicationService` passes the signed_ids to `ProofAttachmentService`
   - `ProofAttachmentService` handles the attachment and status updates
   - All attachments use the same central attachment service for consistency

## Common Issues and Solutions

### Storage Provider Differences

- **Local Storage** (development): Files are stored locally in `storage/` directory
- **S3 Storage** (production): Files are stored in AWS S3 buckets

Direct upload handles these differences automatically, but certain ActiveStorage behaviors differ between environments.

### Attachment Debugging

`ProofAttachmentService` includes extensive logging to help debug attachment issues:

```
PROOF ATTACHMENT INPUT TYPE: [Type of input received]
PROOF ATTACHMENT ENVIRONMENT: [Current Rails environment]
PROOF ATTACHMENT STORAGE SERVICE: [ActiveStorage service class]
```

### Database Validation and Transaction Isolation

Attachment operations are performed outside the main transaction that creates the application record. This ensures transaction isolation and prevents issues when storage operations fail.

## Recommended Testing Approach

1. Test in development with `USE_S3=true` environment variable to simulate production S3 storage
2. Run the paper application direct upload test to verify attachment functionality

## Code Paths

1. Form submission starts in `app/views/admin/paper_applications/new.html.erb`
2. Direct upload handled by `app/javascript/controllers/upload_controller.js`
3. Controller endpoint defined in `app/controllers/admin/paper_applications_controller.rb`
4. Application creation in `app/services/applications/paper_application_service.rb`
5. Attachment handling in `app/services/proof_attachment_service.rb`

## Comparison with Constituent Portal

The paper application upload flow has been modified to match the constituent portal's upload flow, ensuring consistent behavior for both paths:

1. Both use direct uploads to storage
2. Both pass signed_ids to ProofAttachmentService 
3. Both follow the same attachment and status update process

This consistency ensures that attachment behavior is the same regardless of whether uploads are submitted via the constituent portal or by admins through paper applications.
