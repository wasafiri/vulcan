# Paper Application File Uploads

## Overview

This document explains how file uploads work for paper applications in the MAT system.

## Implementation

### Standard Rails File Uploads

As of March 2025, we've simplified the paper application upload process by removing the direct-to-S3 upload mechanism and replacing it with standard Rails file uploads. This change resolves CORS issues that were occurring with direct uploads.

### How It Works

1. **File Selection:**
   - Admin selects a file using the standard file input in the form
   - The JavaScript controller (`upload_controller.js`) tracks the selected file and updates the UI

2. **Form Submission:**
   - When the admin submits the form, Rails handles the file upload as part of the standard form submission process
   - The file is temporarily stored on the server and then uploaded to S3 by Rails' ActiveStorage
   - This eliminates the need for direct browser-to-S3 uploads that were causing CORS issues

3. **Backend Processing:**
   - The `PaperApplicationService` processes the uploaded file
   - Files are attached to the application record using ActiveStorage
   - Proof statuses are updated based on admin selections

### Key Changes

- Removed direct upload endpoint from `Admin::PaperApplicationsController`
- Simplified the JavaScript controller to only handle file selection feedback
- Let Rails standard multipart form handling manage the file uploads
- The form now posts directly to the create action with the file as part of the submission

### Benefits

- Eliminated CORS issues with direct uploads
- Simpler codebase with fewer moving parts
- Consistent file upload mechanism with standard Rails patterns
- Improved reliability for paper application processing

## Troubleshooting

If file uploads fail:

1. **Check File Size:**
   - Ensure the file is under the maximum allowed size (5MB)

2. **Verify File Type:**
   - Supported types: PDF, JPEG, PNG, TIFF, BMP

3. **Server Logs:**
   - Check server logs for ActiveStorage errors
   - Look for S3 configuration issues or permissions problems

4. **Rails Console:**
   - Use `Application.find(id).income_proof.attached?` to verify attachment status
   - Check for `ActiveStorage::Attachment` records related to the application
