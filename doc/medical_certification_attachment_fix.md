# Medical Certification Direct Upload Fix

## Problem

When attempting to upload medical certifications through direct uploads in production, users encountered the following error:

```
Error storing "medical_certification_valid.pdf". Status: 0
```

The logs showed that:
1. The first stage of direct upload to S3 succeeded (Status 200 OK)
2. But the second stage (attaching the uploaded blob to the application record) failed

## Root Cause

The issue was in how `MedicalCertificationAttachmentService` handled the parameters passed from `ApplicationsController`.

For regular file uploads (e.g., from multipart forms), the parameter is an `ActionDispatch::Http::UploadedFile` object with attributes like:
- `tempfile`
- `original_filename` 
- `content_type`

But for ActiveStorage direct uploads, the parameter is an `ActionController::Parameters` object containing a signed blob ID, with a different structure. The service needed to specifically handle this format.

## Solution

1. Added special handling for `ActionController::Parameters` object in `MedicalCertificationAttachmentService#process_attachment_param`:

```ruby
# Handle ActionController::Parameters (direct upload case)
if defined?(ActionController::Parameters) && blob_or_file.is_a?(ActionController::Parameters)
  Rails.logger.info "Processing ActionController::Parameters from direct upload"
  
  # Try different strategies to extract the signed blob ID
  if blob_or_file.respond_to?(:[]) && blob_or_file[:signed_id].present?
    Rails.logger.info "Found signed_id in parameters: #{blob_or_file[:signed_id]}"
    attachment_param = blob_or_file[:signed_id]
  elsif blob_or_file.respond_to?(:[]) && blob_or_file["signed_id"].present?
    Rails.logger.info "Found string-keyed signed_id in parameters: #{blob_or_file["signed_id"]}"
    attachment_param = blob_or_file["signed_id"]
  elsif blob_or_file.respond_to?(:key?) && blob_or_file.key?(:blob_signed_id)
    Rails.logger.info "Found blob_signed_id: #{blob_or_file[:blob_signed_id]}"
    attachment_param = blob_or_file[:blob_signed_id]
  else
    # Try to find any signed ID-like field in the parameters
    Rails.logger.info "Searching for signed ID in parameters"
    found_signed_id = false
    
    if blob_or_file.respond_to?(:each)
      blob_or_file.each do |key, value|
        if value.is_a?(String) && value.start_with?('eyJf')
          Rails.logger.info "Found potential signed_id in field '#{key}': #{value[0..20]}..."
          attachment_param = value
          found_signed_id = true
          break
        end
      end
    end
    
    unless found_signed_id
      Rails.logger.info "Could not find signed_id in parameters, using as-is"
    end
  end
end
```

2. Added enhanced logging in `ApplicationsController#process_accepted_certification` to better diagnose direct upload parameters:

```ruby
# Enhanced debugging for direct uploads
if params[:medical_certification].respond_to?(:content_type)
  Rails.logger.info "Upload type: Regular file upload with content_type: #{params[:medical_certification].content_type}"
elsif params[:medical_certification].respond_to?(:[]) && params[:medical_certification][:signed_id].present?
  Rails.logger.info "Upload type: Direct upload with signed_id: #{params[:medical_certification][:signed_id][0..20]}..."
else
  Rails.logger.info "Upload type: Unknown structure: #{params[:medical_certification].class.name}"
  
  # Try to log relevant attributes that might help in debugging
  if params[:medical_certification].respond_to?(:each_pair)
    Rails.logger.info "Keys in params: #{params[:medical_certification].keys.join(', ')}"
    
    # Look for possible signed ID fields
    params[:medical_certification].each_pair do |k, v|
      if v.is_a?(String) && v.start_with?('eyJf')
        Rails.logger.info "Potential signed ID found in key '#{k}': #{v[0..20]}..."
      end
    end
  end
end
```

## Testing

The fix was tested with:

1. Created a dedicated test case in `test/services/medical_certification_attachment_service_test.rb` to verify handling of:
   - Regular file uploads 
   - Direct uploads with signed IDs
   - Fallback behavior if blob creation fails

2. The enhanced logging will provide much more detailed information about the exact structure of parameters being received, helping diagnose any future issues.

## Lessons Learned

1. When implementing file upload functionality, ensure your services handle both regular multipart uploads and direct uploads via ActiveStorage.

2. Direct uploads involve a two-phase process:
   - First, the file is uploaded directly to storage (S3) 
   - Then, a signed blob ID is submitted with the form
   - Your code must handle this signed blob ID correctly

3. Implement thorough logging around file upload parameters to make debugging easier.

4. Always implement a fallback mechanism to handle unexpected parameter formats.
