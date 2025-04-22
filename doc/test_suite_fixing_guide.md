# Test Suite Fixing Guide (Post FactoryBot Transition)

**Date:** April 22, 2025

## Overview

This document tracks the process of fixing the test suite failures encountered after transitioning from fixtures to FactoryBot and making related setup changes.

**Test Run Summary (Initial):**

*   **Runs:** 598
*   **Assertions:** 1382
*   **Failures:** 34
*   **Errors:** 186
*   **Skips:** 19

## Major Error Categories

1.  **`NoMethodError: undefined method 'users'/'applications'/etc.`:** Tests using fixture accessors (e.g., `users(:admin)`) instead of factories (`create(:admin)`). This is the most frequent error.
2.  **Foreign Key Violations & Record Not Found:** Issues with setting up related data correctly in remaining fixtures or factory sequences.
3.  **Mailer/Mailbox Errors:** Configuration issues (`Delivery method cannot be nil`), routing problems (`undefined method 'mailbox_name'`), or logic errors.
4.  **Status Errors (`ArgumentError: '...' is not a valid status`):** Using incorrect enum values for models like `Voucher`, `Evaluation`, `Application`.
5.  **Controller/Integration Test Failures:** Incorrect response codes (204 vs. 3XX, 404s), missing elements, or authentication issues often stemming from setup problems.
6.  **Assertion Failures:** Specific test expectations not met (HTML elements, counts, booleans).
7.  **Miscellaneous:** `URI::InvalidURIError`, `NameError`, `LoadError`, `MockExpectationError`, SQL assertion failures.

## Fixing Strategy

*   **Incremental Approach:** Fix errors type by type or file by file.
*   **Frequent Testing:** Run specific test files (`bin/rails test path/to/your_test.rb`) or the full suite (`bin/rails test`) after fixes.
*   **Prioritize Systemic Errors:** Address the `NoMethodError` related to fixture accessors first.

## Step-by-Step Plan & Progress Tracking

**Phase 1: Replace Fixture Accessors with Factories (`NoMethodError`)**

*   [ ] **Task:** Identify all test files using `users(...)`, `applications(...)`, etc.
*   [ ] **Action:** Replace fixture accessors with `create(...)` or `build(...)` using FactoryBot syntax. Ensure `FactoryBot::Syntax::Methods` is included in `test_helper.rb`.
*   [ ] **Files to Check (Initial List from Errors):**
    *   [ ] `test/controllers/admin/paper_applications_controller_test.rb`
    *   [ ] `test/lib/two_factor_auth_test.rb`
    *   [ ] `test/services/applications/paper_application_type_consistency_test.rb`
    *   [ ] `test/controllers/vendor_portal/vouchers_controller_test.rb`
    *   [ ] `test/integration/paper_application_mode_switching_test.rb`
    *   [ ] `test/services/applications/audit_log_builder_test.rb`
    *   [ ] `test/controllers/constituent_portal/training_requests_test.rb`
    *   [ ] `test/controllers/vendor_portal/dashboard_controller_test.rb`
    *   [ ] `test/jobs/proof_attachment_metrics_job_test.rb`
    *   [ ] `test/controllers/evaluator/evaluations_controller_test.rb`
    *   [ ] `test/controllers/constituent_portal/income_threshold_test.rb`
    *   [ ] `test/controllers/sessions_controller_test.rb`
    *   [ ] `test/services/applications/paper_application_attachment_test.rb`
    *   [ ] `test/models/constituent_portal/activity_test.rb`
    *   [ ] `test/models/proof_review_test.rb`
    *   [ ] `test/mailers/voucher_notifications_mailer_test.rb`
    *   [ ] `test/integration/inbound_email_flow_test.rb`
    *   [ ] `test/models/proof_review_validation_test.rb`
    *   [ ] `test/controllers/account_recovery_controller_test.rb`
    *   [ ] `test/services/applications/reporting_service_test.rb`
    *   [ ] `test/mailers/message_stream_test.rb`
    *   [ ] `test/mailers/application_notifications_mailer_test.rb`
    *   [ ] `test/services/applications/paper_application_service_test.rb`
    *   [ ] `test/controllers/two_factor_authentication_credential_test.rb`
    *   [ ] `test/mailers/user_mailer_test.rb`
    *   [ ] `test/mailers/medical_provider_mailer_test.rb`
    *   [ ] `test/integration/debug_authentication_test.rb`
    *   [ ] `test/paper_application_direct_upload_test.rb`
    *   [ ] `test/controllers/constituent_portal/guardian_applications_test.rb`
    *   [ ] `test/controllers/constituent_portal/checkbox_test.rb`
    *   [ ] `test/integration/medical_certification_flow_test.rb`
    *   [ ] `test/integration/authentication_verification_test.rb`
    *   [ ] `test/controllers/two_factor_authentication_webauthn_test.rb`
    *   [ ] `test/mailers/training_session_notifications_mailer_test.rb`
    *   [ ] `test/controllers/admin/reports_controller_test.rb`
    *   [ ] `test/mailers/evaluator_mailer_test.rb`
*   [ ] **Progress:** (To be updated)

**Phase 2: Address Data Integrity Issues**

*   [ ] **Task:** Fix Foreign Key Violations (`UrlHelpersInMailersTest`).
*   [ ] **Action:** Review `test/fixtures/application_status_changes.yml` and ensure `application:` labels match `test/fixtures/applications.yml`. Consider replacing with factory creation in tests.
*   [ ] **Task:** Fix `ActiveRecord::RecordNotFound` (`ConstituentProofsSubmissionTest`).
*   [ ] **Action:** Ensure `@application` is correctly created/found in the test `setup` using factories.
*   [ ] **Progress:** (To be updated)

**Phase 3: Resolve Status & Enum Errors**

*   [ ] **Task:** Fix `ArgumentError: '...' is not a valid status`.
*   [ ] **Action:** Check enum definitions in `Voucher`, `Evaluation`, `Application` models. Correct invalid status values in factories, fixtures, and test logic (e.g., use `:not_reviewed` instead of `:pending` if applicable for `ApplicationProofValidationTest`).
*   [ ] **Files to Check:** `CheckVoucherExpirationJobTest`, `EvaluationTest`, `ApplicationProofValidationTest`.
*   [ ] **Progress:** (To be updated)

**Phase 4: Fix Mailer & Mailbox Errors**

*   [ ] **Task:** Fix `RuntimeError: Delivery method cannot be nil`.
*   [ ] **Action:** Verify `config.action_mailer.delivery_method = :test` in `config/environments/test.rb`. Check mailer calls in tests.
*   [ ] **Files to Check:** `RegistrationsMailerTest`, `ApplicationMailboxTest`, `ProofSubmissionMailboxTest`.
*   [ ] **Task:** Fix `NoMethodError: undefined method 'mailbox_name'/'default_mailbox_name'`.
*   [ ] **Action:** Debug mailbox routing and `InboundEmail` object methods. Verify `ApplicationMailbox.default_mailbox_name`.
*   [ ] **Files to Check:** `test/unit/application_mailbox_test.rb`, `test/mailboxes/application_mailbox_test.rb`.
*   [ ] **Task:** Fix `NoMethodError: undefined method 'ingress_password='`.
*   [ ] **Action:** Check Action Mailbox Postmark ingress setup/stubbing for tests.
*   [ ] **Files to Check:** `test/integration/inbound_email_processing_test.rb`.
*   [ ] **Progress:** (To be updated)

**Phase 5: Address Controller/Integration Failures**

*   [ ] **Task:** Fix 404s (`PagesControllerTest`).
*   [ ] **Action:** Verify routes and controller actions.
*   [ ] **Task:** Fix 204s vs. 3XX (`AuthenticationTest`, `Admin::PrintQueueControllerTest`).
*   [ ] **Action:** Check controller logic; update assertions if 204 is correct, otherwise debug.
*   [ ] **Task:** Fix Missing Elements (`Admin::PoliciesControllerTest`).
*   [ ] **Action:** Debug view rendering for the `index` action's form.
*   [ ] **Progress:** (To be updated)

**Phase 6: Correct Assertion Failures**

*   [ ] **Task:** Fix specific assertion failures.
*   [ ] **Action:** Debug individual test logic and expected outcomes.
    *   [ ] `TrainingSessionTest`: Check `scheduled_for` validation and `rescheduling?` logic.
    *   [ ] `ApplicationProofValidationTest`: Debug `validates_attachment` or custom validation for file types.
    *   [ ] `AuthenticationTest`, `RegistrationsControllerTest`: Debug authentication/sign-in flow and redirects.
    *   [ ] `Admin::DashboardControllerTest`: Debug filtering logic.
    *   [ ] `Admin::PrintQueueControllerTest`: Debug response codes/redirects.
    *   [ ] `ProofSubmissionMailboxTest`: Debug email sending assertions.
    *   [ ] `W9ReviewTest`: Check validation logic for vendor type.
    *   [ ] `UserTest`: Check `User.admins` scope SQL generation vs. assertion.
    *   [ ] `MailerHelperTest`: Check `format_date` helper logic and date/time handling.
*   [ ] **Progress:** (To be updated)

**Phase 7: Resolve Miscellaneous Errors**

*   [ ] **Task:** Fix remaining errors (`URI::InvalidURIError`, `NameError`, `LoadError`, `MockExpectationError`, etc.).
*   [ ] **Action:** Address each based on the specific error message and context.
*   [ ] **Progress:** (To be updated)

## Application Workflow Verification (Medical Certification)

*   **Goal:** Ensure tests correctly reflect the application approval workflow, especially regarding medical certifications.
*   **Correct Flow:**
    1.  Income & Residency Proofs Approved.
    2.  `medical_certification_status` -> `:requested`.
    3.  Medical Cert Received -> `medical_certification_status` -> `:received`.
    4.  Admin Approves Cert -> `medical_certification_status` -> `:approved`.
    5.  Application `status` -> `:approved` (auto-triggered).
    6.  Voucher Issuable.
*   **Action:** Review tests in `test/system/admin/applications_test.rb`, `test/models/application_test.rb`, `test/controllers/admin/applications_controller_test.rb`, and service tests. Flag and correct any tests deviating from this flow.
*   **Status:** [ ] To Do

## Existing Documentation Review

*   **Goal:** Check existing files in `doc/` for relevance and accuracy after recent changes.
*   **Files to Review:**
    *   [ ] `doc/attachment_mocking_guide.md` (Relevant to factory/test setup)
    *   [ ] `doc/system_testing_guide.md` (Relevant to test setup)
    *   [ ] `doc/service_objects.md` (Relevant if service logic changed)
    *   [ ] `doc/medical_certification_guide.md` (Relevant to workflow verification)
    *   [ ] `doc/proof_attachment_guide.md` (Relevant to proof handling tests)
*   **Action:** Update or note required changes in these documents based on the fixes implemented.
*   **Status:** [ ] To Do

---

This guide will be updated as fixes are implemented and new issues arise.
