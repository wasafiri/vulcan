# Medical Certification Direct Upload Fix

## Issue 

When uploading medical certification through the admin interface (`admin/applications#show`), users encountered:

```
Error storing "medical_certification_valid.pdf". Status: 0
```

The logs showed that the direct upload to S3 was succeeding (with a 200 OK response to `/rails/active_storage/direct_uploads`), but the subsequent form submission with the signed blob ID was failing.

After our initial form fix, a second error appeared:

```
ActionController::UnfilteredParameters (unable to convert unpermitted parameters to hash)
```

After fixing that, we encountered a third error:

```
Failed to upload medical certification: undefined local variable or method 'action' for class MedicalCertificationAttachmentService
```

## Root Cause

There were three separate issues at play:

1. **Form Implementation**: The form was using the Rails form helper with `direct_upload: true`:
   ```erb
   <%= f.file_field "medical_certification", direct_upload: true, ... %>
   ```

   This was causing issues with how the file data was being submitted to the controller.

2. **Parameter Handling**: The controller was having trouble processing the parameters due to Rails strong parameter filtering. The error `ActionController::UnfilteredParameters` indicates an issue with how the parameters were being accessed.

3. **Undefined Variable**: In the `MedicalCertificationAttachmentService`, there was a reference to an undefined variable `action` in the `update_certification_status` method. The code was trying to use this variable to determine if a notification should be created.

## Solution

The fix required three changes:

### 1. Form Update

We updated the medical certification upload form to use a standard HTML input element instead of the Rails form helper with `direct_upload: true`:

```erb
<!-- Use standard HTML input for direct upload instead of Rails helper -->
<input type="file" 
       name="medical_certification"
       id="medical_certification"
       class="block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100"
       accept=".pdf,.jpg,.jpeg,.png" />
```

### 2. Controller Parameter Handling

We modified the parameter handling in the `process_accepted_certification` method to properly permit and access the parameters:

```ruby
# Before
Rails.logger.info "ACTION CONTROLLER PARAMETERS TO_H: #{params.to_h.inspect}"
submission_method = params[:submission_method].presence || 'admin_upload'

# After
Rails.logger.info "ACTION CONTROLLER PARAMETERS TO_H: #{params.permit!.to_h.inspect}"
submission_method = params.permit(:submission_method)[:submission_method].presence || 'admin_upload'
```

The key change was using `params.permit(:submission_method)` to explicitly permit the parameter before accessing it, which resolved the `UnfilteredParameters` error.

### 3. Fixed Undefined Variable

We fixed the undefined variable issue in the `update_certification_status` method:

```ruby
# Before
action_mapping = {
  accepted: 'medical_certification_approved',
  rejected: 'medical_certification_rejected',
  received: 'medical_certification_received'
}

if action == action_mapping[status.to_sym]
  Notification.create!(...)
end

# After
action_mapping = {
  accepted: 'medical_certification_approved',
  rejected: 'medical_certification_rejected',
  received: 'medical_certification_received'
}

# Get the notification action name based on the status
notification_action = action_mapping[status.to_sym]

# Create notification if we have a valid action for this status
if notification_action.present?
  Notification.create!(
    recipient: application.user,
    actor: admin,
    action: notification_action,
    notifiable: application,
    metadata: metadata
  )
end
```

This fix properly defines and uses the notification action variable, preventing the "undefined variable" error.

## Testing

This combined solution has been tested in both development and production environments to confirm that medical certifications can now be successfully uploaded through the admin interface.

## Related Changes

These changes build on previous fixes to the `MedicalCertificationAttachmentService` where we improved string parameter handling to better accept signed IDs from direct uploads. The combination of service improvements, form updates, and parameter handling fixes ensures reliable file uploads across all environments.
