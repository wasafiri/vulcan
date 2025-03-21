# Paper Application Upload Refactoring (HISTORICAL DOCUMENT)

**Note: This document describes an earlier refactoring effort that has been superseded by our standardized attachment process. See [Proof Attachment Standardization](proof_attachment_standardization.md) for the current implementation.**

## Overview

The paper application upload flow has been refactored to more closely align with the constituent portal's implementation, following Rails conventions and reducing custom code. This document outlines the changes made and the reasoning behind them.

## Key Changes

### 1. Class Consistency

- Replaced `Constituent` with `Users::Constituent` throughout the codebase to ensure consistency with the constituent portal implementation
- This prevents association mismatches when looking up constituents

### 2. Direct Attachment Approach

- Replaced custom proof attachment service with direct Active Storage attachments
- Simplified the code to match constituent portal's more conventional approach
- This makes the code more maintainable and aligned with Rails conventions
- Added special handling for direct upload signed blob IDs to fix file attachment issues

### 3. Transaction & Context Management

- Improved transaction boundaries to wrap all related operations
- Added proper thread-local variable handling to maintain context throughout the paper application process
- Fixed potential leaks by ensuring thread-local variables are always cleared

### 4. Boolean Parameter Handling

- Added explicit boolean parameter casting similar to the constituent portal controller
- This ensures consistent handling of boolean values across both implementations

### 5. Error Handling

- Enhanced error collection and reporting
- Improved error messages for better debugging
- Added logging to track file attachment operations

## Implementation Details

### Service Object

The `PaperApplicationService` now:
- Uses a single transaction for the entire paper application process
- Handles constituent creation/lookup, application creation, and proof uploads in a more organized way
- Follows Rails conventions for file attachments
- Maintains proper thread-local context for paper applications
- Properly handles direct upload signed blob IDs for file attachments

### Controller Updates

The `PaperApplicationsController` now:
- Uses `Users::Constituent` instead of `Constituent`
- Includes boolean parameter casting similar to the constituent portal
- Has improved error handling and reporting

### File Upload Handling

A critical fix was implemented to address the handling of direct uploads:

1. The form contains `direct_upload: true` attribute which causes Rails to pre-upload the files to ActiveStorage
2. With direct uploads, the params contain signed blob IDs rather than file objects
3. The `process_proof` method now detects and correctly processes these signed blob IDs:
   ```ruby
   if blob_or_file.is_a?(String) && blob_or_file.include?("eyJ")
     # It's a signed blob ID from direct upload
     blob = ActiveStorage::Blob.find_signed(blob_or_file)
     @application.send("#{type}_proof").attach(blob)
   else
     # Regular file upload or already a blob
     @application.send("#{type}_proof").attach(blob_or_file)
   end
   ```
4. Additional verification steps ensure the attachment succeeded
5. Enhanced error handling catches and reports any attachment issues

## Testing

The tests have been updated to:
- Use proper model classes
- Validate the correct flow of operations
- Ensure thread-local variables are properly managed

## Future Improvements

- Consider further unifying the constituent portal and admin paper application code
- Explore if more shared concerns could be extracted
- Review any remaining custom proof handling code
