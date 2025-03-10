# Service Objects in the MAT Vulcan Application

## Overview

This document describes the service objects pattern implemented in the MAT Vulcan application. Service objects help encapsulate business logic and provide a more maintainable, testable codebase.

## BaseService

The `BaseService` class provides common functionality for all service objects:

- Error handling and collection
- Logging utilities
- Standardized interface

## Medical Certification Service

The `Applications::MedicalCertificationService` handles medical certification requests in a safe, reliable way that avoids validation issues.

### Purpose

This service was created to address several issues with the previous implementation:

1. **Validation Conflicts**: Previous implementation triggered unrelated model validations
2. **Error Handling**: Lacked robust error handling for edge cases
3. **Maintainability**: Logic was mixed in the controller

### Usage

```ruby
service = Applications::MedicalCertificationService.new(
  application: application,
  actor: current_user
)

if service.request_certification
  # Success path
else
  # Error handling with service.errors
end
```

### Implementation Details

The service:

1. Validates prerequisites (e.g., medical provider email)
2. Uses direct column updates to bypass model validations where appropriate
3. Maintains proper audit trails via timestamps
4. Handles notification creation failures gracefully
5. Uses background jobs for email delivery to improve reliability
6. Logs detailed errors for troubleshooting

## Implementation Details

The service implementation takes a more direct approach, using update_columns to bypass model validations that aren't relevant to the certification process:

```ruby
# Get current time once to ensure consistency
current_time = Time.current

# Use update_columns to bypass validations while maintaining audit trail
application.update_columns(
  medical_certification_requested_at: current_time,
  medical_certification_status: Application.medical_certification_statuses[:requested],
  updated_at: current_time # Ensure timestamp is updated for audit purposes
)
```

This approach:
1. Prevents unrelated validations from blocking the certification process
2. Maintains data integrity through transactions
3. Ensures consistent timestamps across operations
4. Preserves audit trails

## Future Service Object Candidates

Other areas that could benefit from the service object pattern:

1. Proof submission and review
2. Voucher management 
3. Application status transitions
4. User verification processes

## Testing

All service objects are thoroughly tested with RSpec, including:

- Happy path testing
- Error handling
- Edge cases
- Service interaction

See `spec/services` directory for all service tests.
