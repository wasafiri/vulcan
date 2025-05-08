# MAT Vulcan TODOs

This document provides a structured guide for improvements needed in the MAT Vulcan application. The tasks are organized by area of concern, with checkboxes to track progress and detailed context to assist implementation.

## Table of Contents
- [Application Form Enhancements](#application-form-enhancements)
- [Registration Form Improvements](#registration-form-improvements)
- [Admin Review Interface Updates](#admin-review-interface-updates)
- [System Integrations](#system-integrations)
- [Testing Fixes](#testing-fixes)
- [Email Template Improvements](#email-template-improvements)
- [Vendor Onboarding](#vendor-onboarding)

## Application Form Enhancements

### Constituent Portal Application - New Form

- [ ] **Household Size Field Enhancement**
  - Ensure household size field is clearly visible in the UI
  - Current status: Field exists but may need visual improvements for clarity
  - File: `app/views/constituent_portal/applications/new.html.erb`

- [ ] **Annual Income Field Enhancement**
  - Ensure annual income field is clearly visible in the UI
  - Current status: Field exists but may need visual improvements for clarity
  - File: `app/views/constituent_portal/applications/new.html.erb`

- [ ] **Income Threshold Notification**
  - Add clear notification/alert when income exceeds policy maximum for household size
  - Current status: Validation may exist in `application_form` controller but UI alert needs improvement
  - Implementation notes: Should visually alert the user immediately upon entering a value that exceeds the threshold
  - Files: 
    - `app/views/constituent_portal/applications/new.html.erb`
    - `app/javascript/controllers/application_form_controller.js`

- [ ] **Guardian Information Enhancement**
  - Update the guardian section to collect name and contact information when `is_guardian` is checked
  - Current status: The checkbox exists but doesn't reveal fields for guardian's name and contact details
  - Files: 
    - `app/views/constituent_portal/applications/new.html.erb`
    - `app/javascript/controllers/guardian_controller.js` 

- [ ] **Alternate Contact Person Fields**
  - Add fields for alternate contact person (separate from guardian relationship)
  - Should include name, email, and phone
  - Notifications should CC this contact automatically
  - Current status: Not implemented
  - Implementation notes: Will likely require database schema update
  - Files:
    - `app/views/constituent_portal/applications/new.html.erb`
    - `app/models/application.rb` (may need new associations)
    - Mailer templates that send notifications 

- [ ] **Medical Information Release Enhancement**
  - Add MAT's contact information in the consent section: mat.program1@maryland.gov, 800-552-7724, 410-767-7253 (Voice/TTY), 410-801-9618 (Video Phone)
  - Add checkbox for explicit consent to release medical information
  - Current status: Section exists but lacks these details
  - Implementation notes: May require database schema update for storing consent checkbox state
  - Files:
    - `app/views/constituent_portal/applications/new.html.erb`
    - `app/models/application.rb` (for new database column)
    - Potential migration to add new column

- [ ] **Income Proof Documentation Updates**
  - Add to acceptable documentation list: Current, unexpired SSA/SSI/SSDI documentation; current, unexpired Medicaid and/or SNAP award letter; and current, unexpired VA Benefits letter
  - Current status: List is incomplete
  - File: `app/views/constituent_portal/applications/new.html.erb`

- [ ] **Residency Proof Documentation Updates**
  - Add to acceptable documentation list: utility bill, patient photo ID
  - Current status: List is incomplete
  - File: `app/views/constituent_portal/applications/new.html.erb`

- [ ] **Medical Certification Form Updates**
  - Add to list of acceptable medical professionals: occupational therapist, optometrist, or nurse practitioner
  - Current status: List is incomplete
  - File: `app/views/constituent_portal/applications/_medical_provider_form.html.erb` (check this path)

## Registration Form Improvements

- [ ] **State Field Default Selection**
  - Set "MD" as the default selected value for state dropdown in registration form
  - Current status: No default selection
  - File: `app/views/registrations/new.html.erb`

- [ ] **Phone Type Selection**
  - Add field to select phone type (voice or videophone)
  - Current status: Only collects phone number without type differentiation
  - Implementation notes: Will require database schema update
  - Files:
    - `app/views/registrations/new.html.erb`
    - `app/models/user.rb`
    - New migration for adding phone_type column

## Admin Review Interface Updates

- [ ] **Income Proof Review Enhancement**
  - Display income amount from application in the review modal for quick comparison
  - Current status: Missing from review modal
  - Implementation suggestion: Add to modal layout with text like "Income entered during application: $XXX,XXX"
  - Files:
    - `app/views/admin/applications/_modals.html.erb` 
    - Potentially `app/controllers/admin/applications_controller.rb` to ensure the value is available

- [ ] **Residency Proof Review Enhancement**
  - Display address from application in the review modal for quick comparison
  - Current status: Missing from review modal
  - Implementation suggestion: Add to modal layout with text like "Address entered during application: XXX"
  - Files:
    - `app/views/admin/applications/_modals.html.erb`
    - Potentially `app/controllers/admin/applications_controller.rb` to ensure the value is available

## System Integrations

- [ ] **Trainer/Training Debugging**
  - Fix 500 error in trainers/training#index or trainers/training#new
  - Current status: Routes exist but page fails to load
  - Implementation notes: Debugging needed to identify the source of the error
  - Files: 
    - `app/controllers/trainers/training_controller.rb`
    - Related views and models

- [ ] **Email Templates Audit Logging**
  - Add audit logging to email_templates#show similar to other admin pages
  - Ensure logs appear in the admin/applications#index "master" audit log
  - Current status: Missing audit logging
  - Files:
    - `app/controllers/admin/email_templates_controller.rb`
    - `app/models/audit_log.rb` (potentially)

- [ ] **Email Proof Submission Webhook**
  - Verify that webhook for receiving emailed proofs is functional
  - Ensure proper attachment to applications
  - Current status: Functionality exists but needs verification
  - Files:
    - `app/mailboxes/proof_submission_mailbox.rb`
    - Related webhook endpoints

- [ ] **Medical Certification Document Signing**
  - Research and implement document signing integration
  - Options to evaluate: Docusign vs Docuseal (open source)
  - Implementation considerations: Compare features, security, cost, and integration complexity
  - Current status: Not implemented

## Testing Fixes

This section outlines the current state of test failures based on the **May 8, 2025 test log analysis**. 
The "Priority Test Files to Fix" section below is now superseded by "Remaining Test Issues (Based on May 8 Log Analysis)".

*(Previous "Priority Test Files to Fix" section can be removed or archived if this new list is comprehensive)*

### Remaining Test Issues (Based on May 8 Log Analysis)

**Attack Order (Derived from Log):**

1.  **[✓] NameError in Admin Controllers (`Admin::ApplicationsControllerTest`, `Admin::DashboardsControllerTest`, `AuthenticationTest`)**
    *   **Affected Tests:**
        *   `Admin::ApplicationsControllerTest#test_should_get_index`
        *   `Admin::DashboardsControllerTest#test_should_get_index` (and other filter tests)
        *   `AuthenticationTest#test_should_enforce_role-based_access_control`
    *   **Error:** `NameError: '@{data: {current_fiscal_year: 2024, …}}' is not allowed as an instance variable name`
    *   **Location:** `app/controllers/admin/applications_controller.rb:28` (or near, in `index` action's `instance_variable_set` loop).
    *   **Cause:** A key from `report_data` (from `Applications::ReportingService`) like `"data: {current_fiscal_year: 2024, …}"` is being used to create an instance variable name.
    *   **Fix Implemented:**
        *   Created a `SafeInstanceVariables` concern in `app/controllers/concerns/safe_instance_variables.rb` that provides:
            *   `safe_assign(key, value)` - Safely assigns a value to an instance variable after sanitizing the key
            *   `safe_assign_all(hash)` - Safely assigns multiple instance variables from a hash
        *   Included the concern in `Admin::BaseController` so it's available to all admin controllers
        *   Added key sanitization in `Admin::ApplicationsController`, `Admin::DashboardController`, `Admin::ReportsController`, and `Admin::ApplicationAnalyticsController` to strip leading '@' symbols and replace special characters with underscores
        *   This fix ensures all instance variable names are valid Ruby identifiers

2.  **[ ] Factory/Fixture Email Collisions (`TrainingSessionNotificationsMailerTest`)**
    *   **Affected Tests:** `TrainingSessionNotificationsMailerTest` (3 errors)
    *   **Error:** `ActiveRecord::RecordInvalid: Validation failed: Email has already been taken`
    *   **Location:** `test/mailers/training_session_notifications_mailer_test.rb:48`
    *   **Cause:** `:trainer` factory email collisions, possibly due to sequence reset issues or conflict with `users.yml` fixtures.
    *   **Fix Sketch:** Make email sequence more robust (e.g., add `SecureRandom.hex(4)`). Review test setup for unique email usage.

3.  **[ ] Missing Email Templates / ActiveRecord::RecordInvalid (EmailTemplate related)**
    *   **Affected Tests:**
        *   `Applications::PaperApplicationTypeConsistencyTest`: `RuntimeError: Email templates not found for application_notifications_account_created` (at `app/mailers/application_notifications_mailer.rb:381`)
        *   `RegistrationsMailerTest` (2 errors): `ActiveRecord::RecordInvalid: Validation failed: Description can't be blank...` (at `test/unit/registrations_mailer_test.rb:73`, likely due to `EmailTemplate.find_by!` returning nil).
    *   **Cause:** `EmailTemplate.find_by!` failing. Potential issues: test stubs, `DatabaseCleaner` interaction, or incorrect template name in `db/seeds/email_templates.rb`.
    *   **Fix Sketch:** Verify template names in seed file. Review test stubs. Consider explicit `EmailTemplate` creation in test `setup` if global seeding is problematic.

4.  **[ ] `assert_enqueued_email_with` / `assert_enqueued_with` Issues**
    *   **Affected Tests:**
        *   `VoucherTest` (3 failures): `No enqueued job found with {job: ActionMailer::MailDeliveryJob, args: …}`
        *   `InvoiceTest` (1 error): `ArgumentError: unknown keyword: :args` (at `test/test_helper.rb:115` in `assert_enqueued_email_with`).
    *   **Cause:**
        *   `VoucherTest`: Mismatch between expected and actual enqueued job arguments.
        *   `InvoiceTest`: The helper `assert_enqueued_email_with` in `test_helper.rb` is not fully Rails 7 compatible regarding argument passing to underlying assertions.
    *   **Fix Sketch:**
        *   Update `assert_enqueued_email_with` in `test_helper.rb` to correctly pass arguments to Rails 7's `assert_enqueued_with` (avoid keyword `args:` if it's not for the job's payload).
        *   For `VoucherTest`, inspect "Potential matches" and adjust test expectations for job arguments.

5.  **[ ] Service Test Failures (`Applications::FilterServiceTest`, `Applications::ReportingServiceTest`)**
    *   **Affected Tests & Errors:**
        *   `Applications::FilterServiceTest`: `ActiveRecord::RecordInvalid` (Income proof validation at line 92), `NoMethodError: undefined method 'count' for nil` (line 25), multiple `NilClass#include?` or expectation failures (lines 29-198).
        *   `Applications::ReportingServiceTest`: `NoMethodError: undefined method '[]' for nil` (line 62 and others), `Expected nil to respond to #empty?` (line 527).
    *   **Cause:** Tests not correctly handling the `BaseService::Result` object (i.e., not checking `result.success?` and accessing `result.data`). `result.data` might be `nil` if the service call failed. Factory setup issues for `RecordInvalid`.
    *   **Fix Sketch:**
        *   Ensure all tests check `service_result.success?` before `service_result.data`.
        *   For `FilterServiceTest` `RecordInvalid`: Review factory setup at line 92 to include income proof.
        *   Investigate why `service_result.data` is `nil` in failing cases for both service tests.

6.  **[✓] Missing Factory Traits (`EdgeCasesTest`)**
    *   **Affected Tests:** `EdgeCasesTest` (6 errors for various test methods)
    *   **Error:** `KeyError: Trait not registered: "proof_submission_rate_limit_web"`
    *   **Location:** `test/mailboxes/edge_cases_test.rb:25`
    *   **Fix Implemented:** Added the missing traits to the `Policy` factory in `test/factories/policies.rb`:
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

7.  **[ ] Controller Authentication/Authorization & Session Issues**
    *   **Affected Tests & Errors:**
        *   `VendorPortal::DashboardControllerTest`: Expected redirect, got 200 (line 13).
        *   `Evaluators::DashboardsControllerTest`: Expected redirect, got 204 (line 15).
        *   `PasswordVisibilityIntegrationTest`: Expected 2XX, got 302 to `/password/new` (line 38).
        *   `DebugAuthenticationTest`: Expected 200, got 302 after manual cookie injection (line 157).
    *   **Cause:** Auth filters bypassed or not triggering as expected; incorrect manual cookie setting; expired/missing password reset token.
    *   **Fix Sketch:**
        *   `VendorPortal`/`Evaluators`: Ensure no user is signed in during `setup` for tests checking unauthenticated access.
        *   `PasswordVisibilityIntegrationTest`: Create a fresh `PasswordResetToken` in test setup.
        *   `DebugAuthenticationTest`: Verify correct cookie name and signing for manual injection, or use `sign_in` helper.

8.  **[ ] Miscellaneous Test Logic/Setup Issues**
    *   **`ConstituentPortal::GuardianApplicationsTest`:** `Event.count` didn't change by 1 (line 81). Investigate event creation logic in the controller action.
    *   **`MatVulcan::InboundEmailConfigTest`:** `LoadError: cannot load such file -- …/config/initializers/inbound_email_config.rb` (line 64). Check file path or if file is missing.
    *   **`ProofSubmissionFlowTest` (3 errors):** `ActiveRecord::RecordNotFound: Couldn't find Application` (line 12). Fix test setup to ensure `Application` record exists.
    *   **`Applications::EventDeduplicationServiceTest`:** `NameError: undefined local variable or method 'assertion_count'` (line 13). Replace with `assert_equal` or other standard Minitest assertion.
    *   **`ProofAttachmentMetricsJobTest`:** `Should have created 1 notification. Actual: 0` (line 74). Ensure test setup meets job's conditions for creating notification (e.g., application has attachments).
    *   **`ProofAttachmentFallbackTest` (2 errors):** `NoMethodError: undefined method 'applications'` (line 10). Likely a typo, should be `application` or fixture accessor.
    *   **`EvaluatorMailerTest`:** `unexpected invocation: ...queue_for_printing(). expected exactly once, invoked twice` (line 99). Adjust mock expectation (`times: 2`) or investigate mailer logic.
    *   **Web-authn / 2-FA integration tests:** Multiple failures (unexpected redirects, missing cookies). Needs deeper investigation into session/cookie handling in these flows.


## Email Template Improvements

- [ ] **Email Template Testing Fixes**
  - Reference `doc/email_template_testing_fixes.md` for specific issues
  - Current status: Documentation exists but implementation may be incomplete

## Vendor Onboarding

- [ ] **Vendor User Creation Process**
  - Determine best approach for vendor onboarding
  - Options:
    1. Sign up as constituent then admin changes role to vendor
    2. Admin-initiated process (like paper_applications#new) with email to complete setup
  - Implementation notes: Consider security, UX, and administrative overhead
  - Current status: Not clearly defined

- [ ] **Vendor Terms and Conditions**
  - Upload terms and conditions text or link to the Vendor Dashboard
  - Current status: Acceptance UI exists but actual terms are missing
  - Files: Likely in vendor portal views

## Technical Debt & Documentation

- [ ] **Document Vendor Onboarding Decision**
  - Once vendor onboarding approach is decided, document the rationale and implementation details
  - Add to appropriate documentation files in the `docs/` directory

- [ ] **Update System Architecture Documentation**
  - Document any new integrations or major components added (e.g., document signing)
  - Ensure diagram is updated if system architecture changes

---

## Implementation Notes

### Important Conventions
- Follow Rails naming conventions consistently
- Document any deviations from Rails conventions with inline comments and a note in progress.md
- Include usage examples for new features
- Add tests that validate the fixes and new functionality

### Best Practices for Changes
1. Root cause analysis before implementation
2. Verify that fixes don't break existing functionality
3. Run affected tests after changes
4. Search for similar patterns and fix them together when possible
5. Consider UX implications of UI changes
6. Validate changes with real-world scenarios

### Change Verification Process
1. Fix issue in development
2. Add or update tests to cover the change
3. Document the change and any important considerations
4. Verify through manual testing where appropriate
5. Update relevant documentation
