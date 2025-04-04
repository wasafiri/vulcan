# Proof Resubmission Guide

## Overview

The proof resubmission feature allows constituents to submit new proofs when their original proof submissions have been rejected by administrators. This document describes how the feature works, its architecture, and how to maintain it.

## User Flow

1. A constituent submits an application with proof documents (income and residency)
2. An administrator reviews and may reject one or both proofs
3. When a proof is rejected, the constituent receives a notification
4. The constituent logs into the constituent portal and sees their rejected proof(s) on their dashboard
5. The constituent clicks the "Upload New Proof" button for the rejected proof
6. The constituent selects a new file and submits it
7. The new proof is sent to administrators for review

## Feature Components

### Dashboard View

The constituent dashboard (`app/views/constituent_portal/dashboards/show.html.erb`) displays:
- Current status of both proof types (income and residency)
- Rejection reasons and dates if applicable
- Submission counts (showing how many times proof has been resubmitted)
- "Upload New Proof" buttons that only appear for rejected proofs

### Proof Upload Form

The proof upload form (`app/views/constituent_portal/proofs/new.html.erb`) provides:
- Direct upload to S3/ActiveStorage with progress indication
- File validation (size and type)
- Proper error handling

### Controllers

- `ConstituentPortal::DashboardsController`: Provides proof status information including rejection reasons
- `ConstituentPortal::Proofs::ProofsController`: Handles the proof upload workflow with proper validations and security

### JavaScript Controllers

- `UploadController`: Manages the direct upload process, showing progress and handling errors

### Models & Services

- `Application`: Contains status tracking for proofs through the `ProofManageable` concern
- `ProofSubmissionAudit`: Records each submission for auditing and policy enforcement
- `ProofAttachmentService`: Central service for handling all proof attachments

### Policy Enforcement

Rate limiting and maximum resubmission attempts are enforced by:
1. `Policy` settings that define how many resubmissions are allowed
2. Dashboard controller checks for determining eligibility
3. ProofsController validations to prevent excessive submissions

## Resubmission Limits

Constituents are limited in how many times they can resubmit a proof. This limit is defined in the `Policy` model with the `max_proof_submissions` setting. When a constituent reaches this limit, they will no longer see the "Upload New Proof" button and must contact support.

## Technical Implementation

### Direct Uploads

The system uses ActiveStorage direct uploads to:
1. Bypass the application server for large file transfers
2. Provide progress indication to the user
3. Handle files securely

### Auditing

Each proof submission is recorded in `ProofSubmissionAudit` with:
- Timestamp
- Proof type
- User information
- File metadata
- Submission method

### Status Tracking

The application tracks proof statuses with:
- `income_proof_status`: not_reviewed, approved, rejected
- `residency_proof_status`: not_reviewed, approved, rejected

When a proof is resubmitted, its status is reset to `not_reviewed`.

## Common Issues and Solutions

### Status Not Updating

If proof status isn't updating correctly:
1. Check `ProofManageable` concern for the `set_proof_status_to_unreviewed` method
2. Verify that callbacks are firing on attachment changes

### Missing Upload Button

If the upload button doesn't appear for rejected proofs:
1. Confirm proof status is correctly set to `rejected`
2. Check that `can_resubmit_proof?` logic in the dashboard controller is working
3. Verify the user hasn't exceeded maximum resubmission attempts

### Audit Records Missing

If audit records are missing:
1. Check `create_proof_submission_audit` in the `ProofManageable` concern
2. Verify the `ProofSubmissionAudit` model is working correctly

## Maintenance Tips

1. The maximum allowed file size is defined in `ProofManageable::MAX_FILE_SIZE`
2. Allowed file types are defined in `ProofManageable::ALLOWED_TYPES`
3. Resubmission limits are in the `Policy` model, accessible via `Policy.get('max_proof_submissions')`
