# Proof Attachment Monitoring System

This document describes the proof attachment monitoring system that tracks and reports on the success/failure rates of document uploads in the application.

**Note: This document has been updated to reflect the standardized attachment process introduced in [Proof Attachment Standardization](proof_attachment_standardization.md).**

## Overview

The proof attachment monitoring system tracks all proof submissions (both successful and failed) through the `ProofSubmissionAudit` model. This data is then analyzed daily by a scheduled job to identify potential issues with the attachment process and alert administrators when failure rates exceed acceptable thresholds.

## Components

### 1. ProofAttachmentService

This service centralizes all proof attachment logic and provides telemetry for both successful and failed operations. It:

- Records comprehensive metadata about each attachment attempt
- Handles error cases gracefully
- Creates audit records for each operation
- Records timing information for performance monitoring

```ruby
# Example usage:
result = ProofAttachmentService.attach_proof(
  application: application,
  proof_type: "income",
  blob_or_file: uploaded_file,
  status: :approved,
  admin: current_admin,
  metadata: { ip_address: request.remote_ip }
)

if result[:success]
  # Handle success
else
  # Handle failure (error details in result[:error])
end
```

### 2. ProofSubmissionAudit Model

Stores detailed information about each proof submission attempt, including:

- Application and user information
- Proof type (income or residency)
- Submission method (web or paper)
- IP address and other metadata
- Success/failure status
- Error messages when applicable

### 3. Daily Metrics Job

The `ProofAttachmentMetricsJob` analyzes audit data and generates metrics on:

- Overall success/failure rates
- Success/failure rates by proof type
- Success/failure rates by submission method (web vs. paper)

When failure rates exceed 5% with more than 5 failures in the past 24 hours, administrators are automatically notified.

## Schedule Configuration

The metrics job is scheduled via `config/recurring.yml`:

```yaml
proof_attachment_metrics:
  class: ProofAttachmentMetricsJob
  cron: "0 0 * * *"  # At midnight every day
  description: "Generate daily metrics on proof attachment success/failure rates"
  queue: "low"
```

## Testing

The monitoring system is tested through:

1. Unit tests for the ProofAttachmentService
2. Integration tests for attachment operations
3. Job tests that verify metrics calculation and notification thresholds

## Debugging Attachment Issues

When investigating attachment failures:

1. Check application logs for detailed error messages
2. Review the `ProofSubmissionAudit` records for the specific application
3. Look for patterns in the failure metadata (common error types, IP addresses, etc.)
4. Verify S3 connectivity and permissions if failures seem infrastructure-related

## Common Failure Types

Some common reasons for attachment failures:

1. **S3 connectivity issues**: Check network connectivity and S3 service status
2. **File validation failures**: Ensure files meet size and type requirements
3. **Database transaction issues**: Look for transaction nesting or locking problems
4. **Permission errors**: Verify proper IAM permissions for S3 bucket

## Expanding the Monitoring System

To add monitoring for new attachment types:

1. Use the `ProofAttachmentService` for all attachment operations
2. Ensure proper metadata is included in the service calls
3. Update metrics calculations if needed in the `ProofAttachmentMetricsJob`
