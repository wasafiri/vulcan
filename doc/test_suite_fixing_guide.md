# Test Suite Fixing Guide (Post FactoryBot Transition)

**Date:** April 22, 2025
**Updated:** May 8, 2025

## Overview

This document tracks the process of fixing the test suite failures encountered after transitioning from fixtures to FactoryBot and making related setup changes.

**Test Run Summary (Latest Known):**

*   **May 7, 2025 (Before latest fixes):**
    *   **Runs:** 662
    *   **Assertions:** 2404
    *   **Failures:** 23
    *   **Errors:** 39
    *   **Skips:** 21
*   **May 8, 2025 (After initial cluster fixes & new log analysis):**
    *   **Errors:** 24 (approx.)
    *   **Failures:** 12 (approx.)
    *   *(Exact run/assertion counts to be updated after next full test suite run)*

**Summary of Fixes Applied (May 8, 2025 Sprint - Initial):**

*   **Cluster A (Missing path helper `constituent_dashboard_path`):**
    *   Corrected path to `constituent_portal_dashboard_path` in:
        *   `app/controllers/users_controller.rb` (in `after_update_path`)
        *   `app/controllers/application_controller.rb` (in `_dashboard_for`)
        *   `app/views/shared/_header.html.erb` (in `dashboard_path` logic)
*   **Cluster B (Unique-index explosions after global seed):**
    *   Updated user factories (`test/factories/users.rb`) to ensure distinct email sequences for different user types:
        *   `:admin` (already had sequence)
        *   `:evaluator` now uses `evaluator#{n}@example.com`
        *   `:constituent` now uses `constituent#{n}@example.com`
        *   `:vendor_user` now uses `vendor#{n}@example.com`
    *   This prevents email collisions between different factory-generated user types and reduces the likelihood of collision with fixture-loaded users like `user@example.com` or `admin@example.com`.
*   **Cluster C (Service interface drift - `add_error` NoMethodError):**
    *   Updated services to use the `BaseService::Result` pattern (returning `success(data:)` or `failure(message:, data:)`).
        *   `app/services/applications/filter_service.rb`: Modified `apply_filters`.
        *   `app/services/applications/medical_certification_service.rb`: Modified `request_certification`.
        *   `app/services/applications/reporting_service.rb`: Modified `generate_dashboard_data` and `generate_index_data`.
    *   Updated corresponding service tests to expect the `Result` object and check `success?` and `data` or `message` attributes:
        *   `test/services/applications/filter_service_test.rb`
        *   `test/services/applications/reporting_service_test.rb`
*   **Cluster D (ActiveJob API changes - `assert_enqueued_email_with`):**
    *   Updated the `assert_enqueued_email_with` helper in `test/test_helper.rb`:
        *   Renamed `_args:` keyword to `mailer_args:`.
        *   Modified the helper to correctly use `assert_enqueued_with` with `args:` to match against `mailer_class`, `method_name`, and optionally `mailer_args` for `ActionMailer::MailDeliveryJob`.

## Next Steps: Addressing Remaining Test Failures (Based on May 8 Log Analysis)

The following plan is based on the provided test failure logs:

**Priority Order (Derived from Log):**

1.  **NameError in Admin Controllers (`Admin::ApplicationsControllerTest`, `Admin::DashboardsControllerTest`, `AuthenticationTest`)**
2.  **Factory/Fixture Email Collisions (`TrainingSessionNotificationsMailerTest`)**
3.  **Missing Email Templates (`Applications::PaperApplicationTypeConsistencyTest`, `RegistrationsMailerTest`)**
4.  **`assert_enqueued_email_with` / `assert_enqueued_with` issues (`VoucherTest`, `InvoiceTest`)**
5.  **Service Test Failures (`Applications::FilterServiceTest`, `Applications::ReportingServiceTest`)**
6.  **Missing Factory Traits (`EdgeCasesTest`)**
7.  **Controller Authentication/Authorization Issues (`VendorPortal::DashboardControllerTest`, `Evaluators::DashboardsControllerTest`, `DebugAuthenticationTest`)**
8.  **Miscellaneous Test Logic/Setup Issues (various individual tests)**

**Detailed Breakdown of Remaining Issues (from May 8 Logs):**

**1. ✓ NameError: `'@{data: {...}}' is not allowed as an instance variable name` (FIXED)**
    *   **Affected Tests:**
        *   `Admin::ApplicationsControllerTest#test_should_get_index`
        *   `Admin::DashboardsControllerTest#test_should_get_index` (and other filter tests)
        *   `AuthenticationTest#test_should_enforce_role-based_access_control`
    *   **Cause:** `app/controllers/admin/applications_controller.rb:28` (or near line 28, within the `index` action). The code `report_data.each { |key, value| instance_variable_set("@#{key}", value) }` is attempting to set an instance variable with a name derived from a key in `report_data`. One of these keys is a string like `"data: {current_fiscal_year: 2024, …}"`, which is invalid as an instance variable name.
    *   **Fix Implemented:** Created a comprehensive solution for sanitizing instance variable names across all admin controllers:
        1. Created a reusable `SafeInstanceVariables` concern in `app/controllers/concerns/safe_instance_variables.rb` that provides:
           ```ruby
           def safe_assign(key, value)
             # Strip leading @ if present and sanitize key to ensure valid Ruby variable name
             sanitized_key = key.to_s.sub(/\A@/, '').gsub(/[^0-9a-zA-Z_]/, '_')
             instance_variable_set("@#{sanitized_key}", value)
           end
           
           def safe_assign_all(hash)
             hash.each do |key, value|
               safe_assign(key, value)
             end
           end
           ```
        2. Included this concern in `Admin::BaseController` to make it available to all admin controllers.
        3. Updated all affected controllers:
           - `Admin::ApplicationsController`: Enhanced existing sanitization to strip leading '@' symbols
           - `Admin::DashboardController`: Refactored to use safe_assign for all instance variables
           - `Admin::ReportsController`: Complete refactor to use safe_assign throughout
           - `Admin::ApplicationAnalyticsController`: Updated to use safe_assign
         
        This fix ensures all instance variable names are valid Ruby identifiers, preventing the NameError across the entire admin interface.

**2. ActiveRecord::RecordInvalid: Validation failed: Email has already been taken**
    *   **Affected Tests:** `TrainingSessionNotificationsMailerTest` (3 errors)
    *   **Cause:** The `:trainer` factory, despite having `sequence(:email) { |n| "trainer#{n}@example.com" }`, is still causing email collisions. This could be due to:
        *   The sequence not resetting correctly between test examples or runs.
        *   Collision with a fixture like `users.yml` if it contains `trainer@example.com` and the sequence starts at `n=0` or `n=1`.
        *   The test setup itself creating users with conflicting emails.
    *   **Fix Sketch:**
        *   Ensure `DatabaseCleaner` is configured to fully clean between tests.
        *   Make the sequence more robust, e.g., `sequence(:email) { |n| "trainer_#{n}_#{SecureRandom.hex(4)}@example.com" }`.
        *   Review `test/mailers/training_session_notifications_mailer_test.rb:48` and its setup to ensure unique emails are used for all relevant user creations.

**3. Missing Email Templates / ActiveRecord::RecordInvalid (EmailTemplate related)**
    *   **Affected Tests:**
        *   `Applications::PaperApplicationTypeConsistencyTest`: `RuntimeError: Email templates not found for application_notifications_account_created`
        *   `RegistrationsMailerTest` (2 errors): `ActiveRecord::RecordInvalid: Validation failed: Description can't be blank, Body must include...` (likely due to `EmailTemplate.find_by!` failing and subsequent code trying to use `nil`).
    *   **Cause:** `EmailTemplate.find_by!(template_name: '...')` is likely failing because the template isn't in the database when the test runs this line. While `db/seeds.rb` (which calls `db/seeds/email_templates.rb`) is run by `test_helper.rb`, there might be an issue with:
        *   Test-specific stubs overriding or interfering with seeded data.
        *   `DatabaseCleaner` strategy removing templates before they are used.
        *   The specific template name not matching what's in `email_templates.rb`.
    *   **Fix Sketch:**
        *   Verify the template names (e.g., `application_notifications_account_created`) exist in `db/seeds/email_templates.rb`.
        *   Review stubs in the failing tests. If `EmailTemplate.find_by!` is stubbed, ensure the stub returns a valid template object.
        *   Consider explicitly creating necessary `EmailTemplate` records in the `setup` block of these tests if global seeding is unreliable for them.

**4. ✓ `assert_enqueued_email_with` / `assert_enqueued_with` Issues (FIXED)**
    *   **Affected Tests:**
        *   `VoucherTest` (3 failures): `No enqueued job found with {job: ActionMailer::MailDeliveryJob, args: …}`
        *   `InvoiceTest` (1 error): `ArgumentError: unknown keyword: :args` (pointing to `test/test_helper.rb:115`, which is inside `assert_enqueued_email_with`).
    *   **Cause:**
        *   For `VoucherTest`: The arguments provided to `assert_enqueued_email_with` (or `assert_enqueued_with`) are not matching the arguments of the actual enqueued job.
        *   For `InvoiceTest`: In Rails 7, the signature for `assert_enqueued_with` changed regarding how job arguments are matched. The error occurred because our helper was incorrectly passing an array of arguments using the `args:` keyword, when Rails 7 requires a proc for flexible argument matching.
    *   **Fix Applied:**
        *   Updated the `assert_enqueued_email_with` helper in `test/test_helper.rb` to use a proper matcher proc for job arguments:
            ```ruby
            # When mailer_args are provided:
            final_args = base_job_args.dup
            if mailer_args.is_a?(Array)
              final_args.concat(mailer_args)
            else
              final_args.push(mailer_args)
            end

            # Create a matcher proc that compares actual job args with expected args
            args_matcher = lambda { |*actual_args|
              actual_args.length == final_args.length &&
                actual_args.zip(final_args).all? { |actual, expected| actual == expected }
            }

            assert_enqueued_with(job: ActionMailer::MailDeliveryJob, args: args_matcher) do
              block_result = yield
            end
            ```
        *   This approach creates a custom matcher proc that compares each actual argument with each expected argument, ensuring precise matching while remaining compatible with Rails 7's API.

**5. Service Test Failures (`Applications::FilterServiceTest`, `Applications::ReportingServiceTest`)**
    *   **Affected Tests:**
        *   `Applications::FilterServiceTest`: `ActiveRecord::RecordInvalid` (Income proof validation), `NoMethodError: undefined method 'count' for nil`, and multiple `NilClass#include?` or expectation failures.
        *   `Applications::ReportingServiceTest`: `NoMethodError: undefined method '[]' for nil`, `Expected nil to respond to #empty?`.
    *   **Cause:**
        *   `FilterServiceTest`:
            *   The `RecordInvalid` suggests a factory setup issue where an application is created without necessary income proof for a test that requires it.
            *   `NoMethodError: undefined method 'count' for nil` and other `NilClass` errors indicate that `service_result.data` is `nil` when the test expects a collection or hash. This means the service call failed (`service_result.success?` is false) or returned `nil` data even on success.
        *   `ReportingServiceTest`: Similar `NoMethodError` and `nil` issues suggest that `service_result.data` is `nil` where a hash is expected.
    *   **Fix Sketch:**
        *   **For both:** Ensure all tests correctly check `service_result.success?` before accessing `service_result.data`. If `success?` is false, `service_result.message` should be inspected or asserted.
        *   **For `FilterServiceTest` `RecordInvalid`:** Review the setup for `test_filters_by_medical_certifications_to_review` (line 92) and ensure the factory call (`create(:application)`) includes necessary traits or attributes for income proof if the filter logic relies on it.
        *   **For `FilterServiceTest` `NoMethodError` on `count` (line 25):** The `apply_filters` method in the service, or the test setup, is resulting in `service_result.data` being `nil`.
        *   **For `ReportingServiceTest` `NoMethodError` on `[]` (line 62):** The `generate_dashboard_data` (or other tested method) is resulting in `service_result.data` being `nil`.

**6. ✓ Missing Factory Traits (`EdgeCasesTest`) (FIXED)**
    *   **Affected Tests:** `EdgeCasesTest` (6 errors)
    *   **Cause:** `KeyError: Trait not registered: "proof_submission_rate_limit_web"` (at `test/mailboxes/edge_cases_test.rb:25`).
    *   **Fix Implemented:**
        *   Added the missing traits to the Policy factory in `test/factories/policies.rb` after analyzing how these traits are used in the test:
        ```ruby
        # Rate limiting traits
        trait :proof_submission_rate_limit_web do
          key { 'proof_submission_rate_limit_web' }
          value { 10 } # Allow 10 submissions via web
        end

        trait :proof_submission_rate_limit_email do
          key { 'proof_submission_rate_limit_email' }
          value { 5 } # Allow 5 submissions via email
        end

        trait :proof_submission_rate_period do
          key { 'proof_submission_rate_period' }
          value { 24 } # Period of 24 hours
        end

        trait :max_proof_rejections do
          key { 'max_proof_rejections' }
          value { 3 } # Maximum of 3 rejections allowed
        end
        ```
        *   These policy traits are used in EdgeCasesTest's setup to create rate limiting policies for testing proof submission edge cases via the mailbox system.
        *   Confirmed fix by running `bin/rails test test/mailboxes/edge_cases_test.rb` which now passes with 0 errors.

**7. Controller Authentication/Authorization Issues**
    *   **Affected Tests:**
        *   `VendorPortal::DashboardControllerTest`: Expected redirect, got 200.
        *   `Evaluators::DashboardsControllerTest`: Expected redirect, got 204.
        *   `DebugAuthenticationTest`: Expected 200, got 302 after manual cookie injection.
        *   `PasswordVisibilityIntegrationTest`: Expected 2XX, got 302 to `/password/new`.
    *   **Cause:**
        *   `VendorPortal` & `Evaluators`: Authentication filters (`require_vendor_login`, `require_evaluator_login`) might not be triggering correctly in tests that are supposed to check unauthenticated access. Standard sign-in helpers might be called in `setup`.
        *   `DebugAuthenticationTest`: Manual cookie setting might be incorrect due to changes in session management or cookie signing.
        *   `PasswordVisibilityIntegrationTest`: The redirect to `/password/new` suggests an issue with password reset token setup or an authentication step kicking in unexpectedly.
    *   **Fix Sketch:**
        *   `VendorPortal` & `Evaluators`: For tests checking auth requirements, ensure no user is signed in during `setup`.
        *   `DebugAuthenticationTest`: Verify the correct cookie name and how to set signed cookies if applicable. Consider using `sign_in(@user)` if direct manipulation is too fragile.
        *   `PasswordVisibilityIntegrationTest`: Ensure a valid, non-expired `PasswordResetToken` is created for the user in the test setup.

**8. Miscellaneous Test Logic/Setup Issues**
    *   **`ConstituentPortal::GuardianApplicationsTest`:** `Event.count` didn't change. The update action might not be creating an event as expected, or the event creation is failing silently.
    *   **`MatVulcan::InboundEmailConfigTest`:** `LoadError: cannot load such file -- …/config/initializers/inbound_email_config.rb`. The file path seems incorrect or the file is missing.
    *   **`ProofSubmissionFlowTest` (3 errors):** `ActiveRecord::RecordNotFound: Couldn't find Application`. Test setup is failing to create or find the necessary `Application` record.
    *   **`Applications::EventDeduplicationServiceTest`:** `NameError: undefined local variable or method 'assertion_count'`. This test file seems to be using a Minitest internal or a helper that's not available/misspelled.
    *   **`ProofAttachmentMetricsJobTest`:** `Should have created 1 notification. Actual: 0`. The job's conditions for creating a notification are not met by the test setup (e.g., application needs attachments).
    *   **`ProofAttachmentFallbackTest` (2 errors):** `NoMethodError: undefined method 'applications'`. Likely a typo in the test, trying to call `applications` (plural) instead of `application` (singular) or a fixture accessor like `applications(:one)`.
    *   **`EvaluatorMailerTest`:** `unexpected invocation: ...queue_for_printing(). expected exactly once, invoked twice`. The `Letters::TextTemplateToPdfService.queue_for_printing` method is being called more times than the mock expects. Adjust mock or investigate mailer logic.

This updated breakdown should provide a clearer path forward.

---
*(Previous content of the guide follows, tracking earlier fixes)*

## Overview (Historical)

This document tracks the process of fixing the test suite failures encountered after transitioning from fixtures to FactoryBot and making related setup changes.

**Test Run Summary (Historical):**

*   **Initial (Before Fixes):**
    *   **Runs:** 598
    *   **Assertions:** 1382
    *   **Failures:** 34
    *   **Errors:** 186
    *   **Skips:** 19

*   **Step 1 (April 22, 2025):**
    *   **Runs:** 598
    *   **Assertions:** 1941
    *   **Failures:** 38
    *   **Errors:** 100
    *   **Skips:** 21

*   **Step 2 (May 7, 2025):**
    *   **Runs:** 662
    *   **Assertions:** 2404
    *   **Failures:** 23
    *   **Errors:** 39
    *   **Skips:** 21
    
*   **Progress (Historical):**
    * Fixed route helper stubs in ApplicationNotificationsMailerTest
    * Fixed enum issues in CheckVoucherExpirationJobTest
    * Fixed TrainingSessionNotificationsMailerTest with proper factory usage
    * Successfully resolving the most critical issues has reduced errors by 47% (from 186 to 100)
    * Fixed paper_applications_controller_test.rb with proper factory setup and mocking
    * Addressed email delivery test issues in various mailer tests

## Major Error Categories (Historical)

1.  **`NoMethodError: undefined method 'users'/'applications'/etc.`:** Tests using fixture accessors (e.g., `users(:admin)`) instead of factories (`create(:admin)`). Still the most frequent error (41 of 109 errors), though we've fixed several key files.
2.  **Foreign Key Violations & Record Not Found:** Issues with setting up related data correctly in remaining fixtures or factory sequences. Several `ActiveRecord::RecordNotFound` and `PG::ForeignKeyViolation` errors in test run.
3.  **Mailer/Mailbox Errors:** 
    * ✓ Basic mailer issues have been fixed in standard mailer tests
    * ✓ All mailer tests now passing (including Training Session Notifications)
    * ⚠️ Remaining mailbox issues: Configuration problems (`Delivery method cannot be nil`), routing errors (`undefined method 'mailbox_name'`), and ingress setup issues (`undefined method 'ingress_password='`)
4.  **Status Errors (`ArgumentError: '...' is not a valid status`):** Using incorrect enum values for models like `Voucher` (✓ fixed: using `:active` instead of `:issued`), `Evaluation` (showing 'requested' instead of :pending), and `Application` ('pending' not valid for income_proof_status).
5.  **Controller/Integration Test Failures:** Several response code issues remain (204 vs. 3XX in AuthenticationTest and Admin::PrintQueueControllerTest), 404s in PagesControllerTest, and missing form elements in Admin::PoliciesControllerTest.
6.  **Assertion Failures:** Specific test expectations not met, including MailerHelperTest date formatting (March 10, 2025 vs March 10 2025), TrainingSessionTest validation failures, and W9ReviewTest validation issues.
7.  **Miscellaneous:** `LoadError` for missing files, `MockExpectationError` in RegistrationsMailerTest, and SQL assertion failures in UserTest (STI class name changed to 'Users::Administrator').

## Fixing Strategy (Historical)

*   **Incremental Approach:** Fix errors type by type or file by file.
*   **Frequent Testing:** Run specific test files (`bin/rails test path/to/your_test.rb`) or the full suite (`bin/rails test`) after fixes.
*   **Prioritize Systemic Errors:** Address the `NoMethodError` related to fixture accessors first.

## Step-by-Step Plan & Progress Tracking (Historical)

*(Content from previous phases of fixes, now marked as historical or completed)*
