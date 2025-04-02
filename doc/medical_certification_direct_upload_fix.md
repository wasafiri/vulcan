# Medical Certification Direct Upload Fix

## Issue 

When uploading medical certification through the admin interface (`admin/applications#show`), users encountered:

```
Error storing "medical_certification_valid.pdf". Status: 0
```

The logs showed that the direct upload to S3 was succeeding (with a 200 OK response to `/rails/active_storage/direct_uploads`), but the subsequent form submission with the signed blob ID was failing.

## Root Cause

The root cause was identified as a mismatch between how the file input was implemented in the form and how the controller expected to receive the file data:

1. The form was using the Rails form helper with `direct_upload: true`:
   ```erb
   <%= f.file_field "medical_certification", direct_upload: true, ... %>
   ```

2. This configuration uses JavaScript to first upload the file to S3 and then submits only the signed blob ID.

3. Even though the `MedicalCertificationAttachmentService` had been updated to handle string inputs as signed IDs, the way the form was submitting the data was still causing issues.

## Solution

We updated the medical certification upload form to use a standard HTML input element instead of the Rails form helper with `direct_upload: true`. This approach matches how file uploads are handled in the paper application upload form, which was working correctly:

```erb
<!-- Use standard HTML input for direct upload instead of Rails helper -->
<input type="file" 
       name="medical_certification"
       id="medical_certification"
       class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100"
       accept=".pdf,.jpg,.jpeg,.png" />
```

This change ensures the file data is sent in a format that the controller can reliably process, making the file upload more robust.

## Testing

This fix has been tested in both development and production environments to confirm that medical certifications can now be successfully uploaded through the admin interface.

## Related Changes

These changes build on previous fixes to the `MedicalCertificationAttachmentService` where we improved string parameter handling to better accept signed IDs from direct uploads. The combination of those service improvements and this form update ensures reliable file uploads across all environments.
