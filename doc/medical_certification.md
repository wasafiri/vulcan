# Medical Certification Process

## Overview

The medical certification process allows constituents to request certification of their disability from a medical provider. Administrators can send these requests via email, and the application tracks the history of these requests.

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

### Jobs

- **MedicalCertificationEmailJob**: Background job for email delivery
  - Ensures reliable email delivery
  - Provides retry capability for transient failures
  - Decouples request processing from email delivery

### Controllers

- **Admin::ApplicationsController**: Provides interface for admins to request certifications
- **ConstituentPortal::ApplicationsController**: Shows certification status to constituents

### Views

- **Admin view**: Shows detailed certification history with timestamps
- **Constituent view**: Displays certification status, provider info, and request history

## Implementation Details

### Tracking Request History

We use a notification-based approach to track the history of certification requests:

1. Each request creates a notification with metadata including timestamp and request number
2. Views query the notification table to display the history
3. This provides a reliable audit trail of all requests

### Background Processing

Email delivery is handled in a background job to:

1. Improve request handling performance
2. Allow for retries of failed deliveries
3. Prevent email failures from affecting the user experience

### Error Handling

The service object pattern enables comprehensive error handling:

1. Validation errors are captured before attempting updates
2. Database transactions ensure data consistency
3. Errors are logged and presented to users in a friendly manner

## Testing

The implementation includes comprehensive test coverage:

1. **Unit tests** for service objects
2. **Controller tests** for request handling
3. **Integration tests** for the full request flow
4. **System tests** for browser-based interaction

## User Experience

### Admin Experience

Administrators can:
- Send initial certification requests
- Resend requests if needed
- View the complete history of requests
- See error messages for invalid requests

### Constituent Experience

Constituents can:
- See their certification status
- View their medical provider information
- See the history of requests
- Track when requests were sent

## Future Improvements

Potential enhancements to consider:

1. **Email templating**: Allow customization of certification request emails
2. **Provider portal**: Create a dedicated portal for medical providers to submit certifications
3. **Auto-reminders**: Automatically send follow-up requests after a defined period
4. **Status webhooks**: Integrate with external systems to update certification status
