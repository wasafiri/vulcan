# Paper Application File Uploads

## Overview

This document explains how file uploads work for paper applications in the MAT system.

## Implementation

### Direct Upload to S3

The paper application upload process uses Rails' built-in direct upload functionality, which allows files to be uploaded directly from the browser to S3. This is the same approach used in the constituent portal, providing a consistent and reliable upload mechanism across the application.

### How It Works

1. **File Selection:**
   - Admin selects a file using the file input in the form
   - The JavaScript controller (`upload_controller.js`) tracks the selected file and updates the UI
   - The file input is configured with `direct_upload: true` and `rails_direct_uploads_url` to use Rails' built-in direct upload endpoint
   - We use Rails' standard direct upload functionality (/rails/active_storage/direct_uploads) for consistent behavior across the application

2. **Direct Upload Process:**
   - When a file is selected, Rails' direct upload mechanism creates a blob record
   - The browser uploads the file directly to S3 using pre-signed URLs
   - Progress is tracked and displayed to the user through the UI
   - The signed blob ID is stored in a hidden field for form submission

3. **Form Submission:**
   - When the admin submits the form, the signed blob ID is included
   - The `PaperApplicationService` processes the uploaded file using the blob
   - Files are attached to the application record using ActiveStorage
   - Proof statuses are updated based on admin selections

### Key Components

- **Controller:** `Admin::PaperApplicationsController` handles the form submission
- **JavaScript:** `upload_controller.js` manages the direct upload UI and progress tracking (shared with constituent portal)
- **Service:** `PaperApplicationService` processes the uploaded files and creates the application record
- **View:** The form in `new.html.erb` configures file inputs to use Rails' direct upload endpoint

### Benefits

- Direct browser-to-S3 uploads improve performance by bypassing the application server
- Progress tracking provides better user feedback during uploads
- Consistent upload mechanism with the constituent portal
- Built-in error handling and retry capabilities
- Shared JavaScript controller reduces code duplication
- Uses Rails' standard direct upload endpoint which:
  - Handles CSRF protection automatically
  - Manages blob creation and direct upload URLs
  - Provides consistent behavior across the application
  - Eliminates need for custom upload endpoints

## Troubleshooting

If file uploads fail:

1. **Check File Size:**
   - Ensure the file is under the maximum allowed size (5MB)

2. **Verify File Type:**
   - Supported types: PDF, JPEG, PNG, TIFF, BMP

3. **Check Browser Console:**
   - Look for JavaScript errors during upload
   - Check network requests for direct upload issues

4. **Server Logs:**
   - Check for ActiveStorage errors
   - Look for S3 configuration issues or permissions problems

5. **Rails Console:**
   - Use `Application.find(id).income_proof.attached?` to verify attachment status
   - Check for `ActiveStorage::Blob` and `ActiveStorage::Attachment` records
