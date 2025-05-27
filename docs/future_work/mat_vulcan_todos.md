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

- [x] **Household Size Field Enhancement**
  - Ensure household size field is clearly visible in the UI
  - Current status: Field exists but may need visual improvements for clarity
  - File: `app/views/constituent_portal/applications/new.html.erb`
  - **Update:** Changed input field border color to `border-gray-500` in `app/views/constituent_portal/applications/new.html.erb` to improve visibility against the background.

- [x] **Annual Income Field Enhancement**
  - Ensure annual income field is clearly visible in the UI
  - Current status: COMPLETED
  - File: `app/views/constituent_portal/applications/new.html.erb`
  - **Update:** Enhanced field visibility with border-gray-500, added structured container with dollar sign prefix, improved accessibility with ARIA attributes, implemented real-time income threshold validation against Policy model values. JavaScript controller now properly formats currency values while preserving raw values for validation.

- [x] **Income Threshold Notification**
  - Add clear notification/alert when income exceeds policy maximum for household size
  - Current status: COMPLETED
  - Implementation notes: Implemented real-time validation against FPL thresholds loaded from the Policy model
  - Files: 
    - `app/views/constituent_portal/applications/new.html.erb`
    - `app/javascript/controllers/application_form_controller.js`
  - **Update:** Enhanced JavaScript controller now fetches FPL thresholds from database via AJAX, validates income against proper household size threshold, displays prominent error message, disables submit button, and announces validation failures to screen readers for accessibility.

- [x] **Guardian Information Refactor**
  - **Status: COMPLETE.** The old `is_guardian` checkbox and direct user fields for guardian info have been replaced by the `GuardianRelationship` model and `managing_guardian_id` on the `Application` model.
  - **Constituent Portal UI:** Fully implemented with comprehensive dependent management features
    - Users can add/manage dependents via `ConstituentPortal::DependentsController` with full CRUD operations
    - When creating a new application (`app/views/constituent_portal/applications/new.html.erb`), users can select themselves or an existing dependent
    - Dashboard shows both personal and dependent applications with clear status indicators
    - Enhanced UI for guardians managing multiple dependents with mixed application states
  - **Admin Portal UI:** Fully implemented with guardian relationship management
    - Paper application form (`app/views/admin/paper_applications/new.html.erb`) allows selecting/creating guardians and dependents
    - User show/index pages (`app/views/admin/users/`) display guardian/dependent relationships with management tools
    - Admin interface for creating and managing guardian relationships (`Admin::GuardianRelationshipsController`)
  - **Implementation Details:**
    - `GuardianRelationship` model with proper validations and unique constraints
    - `User` model with comprehensive associations: `guardian_relationships_as_guardian`, `dependents`, `guardians`, `managed_applications`
    - `Application` model with `managing_guardian_id`, scopes for filtering, and automatic guardian assignment
    - Enhanced filtering and search capabilities in admin interface
    - Comprehensive audit trails for guardian-related actions
    - Security controls preventing unauthorized access to dependent data

- [x] **Alternate Contact Person Fields**
  - **Status: COMPLETE.**
  - Database fields (`alternate_contact_name`, `alternate_contact_phone`, `alternate_contact_email`) exist on the `applications` table.
  - Form fields are present in both constituent portal and admin applications
  - `Application#log_alternate_contact_changes` callback tracks changes to alternate contact fields
  - Notifications properly consider alternate contacts

- [x] **Medical Information Release Enhancement in @/app/views/constituent_portal/applications#new.html.erb **
  - **Status: COMPLETE.** Enhanced and merged medical information sections for optimal UX.
  - **Implementation Details:**
    - **Merged Sections:** Combined "Medical Professional Information" and "Medical Information Release Authorization" into a single, cohesive section titled "Medical Professional Information and Authorization to Contact"
    - **Enhanced Authorization Section:** Replaced simple text consent with comprehensive authorization that includes:
      - MAT contact information in a prominent white box (email, phone, Voice/TTY, Video Phone - all clickable links)
      - Clear bullet-point explanation of what authorization covers (provider contact, documentation sharing, MAT communication)
      - **Required checkbox** using existing `medical_release_authorized` database field
      - Proper ARIA accessibility attributes and error messaging
    - **Improved UX Flow:** Medical provider fields → Clear explanation of consent → Required authorization checkbox
    - **Enhanced Styling:** Blue-themed section with visual hierarchy, border separation for the checkbox area
  - **Files Modified:**
    - `app/views/constituent_portal/applications/_medical_provider_form.html.erb` - Enhanced with merged authorization content
    - `app/views/constituent_portal/applications/new.html.erb` - Removed duplicate standalone authorization section
  - **Database:** No migration needed - utilized existing `medical_release_authorized` boolean field
  - **Controller:** No changes needed - `medical_release_authorized` already permitted in `application_params`
  - **UX Benefits:** 
    - Reduced cognitive load by eliminating duplicate medical sections
    - Logical information flow: collect info → understand consent → provide authorization
    - Better accessibility with proper labeling and descriptions
    - Visual prominence for required authorization checkbox

- [x] **Income Proof Documentation Updates**
  - **Status: COMPLETE.** Added all required acceptable documentation types to the income verification section.
  - **Implementation Details:**
    - Enhanced the income proof description to include comprehensive list of acceptable documents
    - Added **current, unexpired SSA/SSI/SSDI documentation** as acceptable proof
    - Added **current, unexpired Medicaid and/or SNAP award letter** as acceptable proof  
    - Added **current, unexpired VA Benefits letter** as acceptable proof
    - Maintained existing acceptable documents: tax returns (preferred), current year SSA award letters, recent bank statements
    - Used bold formatting to make document types easily scannable for users
    - Improved readability by restructuring text to "Please provide one of the following acceptable documents:"
    - **Ensured Consistency:** Updated all forms and views that reference income proof documentation
  - **Files Modified:**
    - `app/views/constituent_portal/applications/new.html.erb` - Updated income proof documentation description
    - `app/views/constituent_portal/proofs/proofs/new.html.erb` - Updated proof resubmission form for consistency
    - `app/views/admin/paper_applications/_proof_upload.html.erb` - Updated admin paper application form for consistency
  - **UX Benefits:**
    - Clearer guidance for applicants on acceptable income documentation
    - Expanded options reduce barriers for applicants who may not have traditional income documents
    - Bold formatting makes document types easy to scan and identify

- [x] **Residency Proof Documentation Updates**
  - Add to acceptable documentation list: utility bill, patient photo ID
  - **Status: COMPLETE.** Both utility bill and patient photo ID have been added to the acceptable documentation list.
  - File: `app/views/constituent_portal/applications/new.html.erb`

- [x] **Medical Certification Form Updates**
  - Update list of acceptable medical professionals to include occupational therapist, optometrist, and nurse practitioner
  - **Status: COMPLETE.** The list in `app/views/constituent_portal/applications/_medical_provider_form.html.erb` now includes these professionals.
  - Changes made: Added occupational therapist, optometrist, and nurse practitioner to the list of qualified medical professionals

## Registration Form Improvements

- [x] **State Field Default Selection**
  - Set "MD" as the default selected value for state dropdown in registration form
  - **Status: COMPLETE.** MD is now set as the default in both registration and application forms.
  - Files: 
    - `app/views/registrations/new.html.erb` (now has MD default)
    - `app/views/constituent_portal/applications/new.html.erb` (already had MD default)

- [x] **Phone Type Selection**
  - Add field to select phone type (voice, videophone, or text)
  - **Status: COMPLETE AND TESTED** - Full phone type selection feature implemented and verified working across all forms
  - **Implementation Details:**
    - **Database:** phone_type column with default 'voice' and index
    - **User Model:** enum with `{ voice: 0, videophone: 1, text: 2 }` options
    - **Registration Form:** Complete with voice/videophone/text radio buttons
    - **User Profile Edit:** Phone and phone_type fields added with full form implementation
    - **Dependent Management:** Phone_type selection added to dependent creation/edit forms
    - **Admin Forms:** Phone_type added to paper applications guardian creation and admin user edit
    - **Controllers:** All relevant controllers updated to permit phone_type parameter
    - **Consistency:** All forms with phone fields now include phone_type selection
    - **Bug Fixes:** Fixed radio button selection display issue in dependent forms
    - **Validation:** Fixed uniqueness validation for dependents sharing guardian contact info
     - **Files Modified:**
     - `app/models/user.rb` (phone_type enum with voice/videophone/text options)
     - `app/views/registrations/new.html.erb` (voice/videophone/text radio buttons)
     - `app/views/users/edit.html.erb` (added phone and phone_type fields)
     - `app/views/constituent_portal/dependents/_form.html.erb` (added phone_type selection, fixed radio button display)
     - `app/views/admin/paper_applications/new.html.erb` (added phone_type for guardian creation)
     - `app/views/admin/users/edit.html.erb` (implemented full admin user edit form)
     - `app/controllers/registrations_controller.rb` (permits phone_type)
     - `app/controllers/users_controller.rb` (permits phone/phone_type in user_params)
     - `app/controllers/constituent_portal/dependents_controller.rb` (permits phone_type, fixed contact uniqueness validation)
     - `app/controllers/admin/users_controller.rb` (added edit/update actions and admin_user_params)
     - `app/controllers/admin/paper_applications_controller.rb` (added phone_type to USER_BASE_FIELDS)
     - `db/migrate/20250527170536_add_phone_type_to_users.rb` (migration created and run)

## Admin Review Interface Updates

- [x] **Proof Review Modal Context Enhancement**
  - **Status: COMPLETE.** Enhanced proof review modals to display relevant application context information for better admin decision-making.
  - **Implementation Details:**
    - **Income Proof Review:** Now displays the income amount and household size entered during application submission
    - **Residency Proof Review:** Now displays the address information entered during application submission
    - **Guardian Applications:** Enhanced context shows both guardian and dependent information appropriately
    - **Fallback Logic:** Gracefully handles cases where address information might be missing
  - **Critical Bug Fix:** Discovered and fixed a major issue where address information from application forms was not being saved to the user model
    - **Root Cause:** Address fields were excluded from `application_params` but the `extract_address_attributes` method wasn't being called during application creation
    - **Fix:** Updated `ConstituentPortal::ApplicationsController#create` to properly extract and save address information to the user model
    - **Testing:** Added comprehensive tests to verify address information is saved for both self-applications and guardian/dependent applications
  - **Files Modified:**
    - `app/views/admin/applications/_modals.html.erb` - Enhanced guardian alert section with contextual information
    - `app/controllers/constituent_portal/applications_controller.rb` - Fixed address saving logic
    - `test/controllers/constituent_portal/applications_controller_test.rb` - Added comprehensive address persistence tests
  - **UX Benefits:**
    - Admins can now quickly verify income amounts against submitted documentation
    - Admins can easily compare addresses on residency proofs with application data
    - Reduced need to navigate between proof review and application details
    - Better context for making approval/rejection decisions



## System Integrations

- [x] **Trainer/Training Debugging**
  - Fix 500 error in trainers/training#index or trainers/training#new
  - **Status: COMPLETE/OBSOLETE.** The routes `trainers/training#index` and `trainers/training#new` do not exist in the current application. The actual routes are `trainers/training_sessions` which are working correctly. This TODO appears to reference an old route structure that has been refactored.
  - Files: 
    - `app/controllers/trainers/training_sessions_controller.rb` (working correctly)
    - Related views and models

- [x] **Email Templates Audit Logging**
  - Add audit logging to email_templates#show similar to other admin pages
  - Ensure logs appear in the admin/applications#index "master" audit log
  - **Status: COMPLETE.** Added comprehensive audit logging to email templates controller for view, update, and test email actions using Event.create! pattern.
  - Files:
    - `app/controllers/admin/email_templates_controller.rb` (added audit logging for show, update, and send_test actions)
    - Events are logged with action types: 'email_template_viewed', 'email_template_updated', 'email_template_test_sent'

- [x] **Email Proof Submission Webhook**
  - Verify that webhook for receiving emailed proofs is functional
  - Ensure proper attachment to applications
  - **Status: COMPLETE.** The webhook functionality is fully implemented and functional with comprehensive error handling, rate limiting, and audit logging.
  - Files:
    - `app/mailboxes/proof_submission_mailbox.rb` (comprehensive implementation with validation, rate limiting, and audit logging)
    - `app/controllers/webhooks/email_events_controller.rb` (webhook endpoint for email events)
    - `app/services/email_event_handler.rb` (handles bounce and complaint events)
    - ActionMailbox routes configured for Postmark and other email providers
    - Comprehensive test coverage in `test/mailboxes/proof_submission_mailbox_test.rb`

- [ ] **Medical Certification Document Signing**
  - Research and implement document signing integration
  - Options to evaluate: Docusign vs Docuseal (open source)
  - Implementation considerations: Compare features, security, cost, and integration complexity
  - Current status: Not implemented

## Testing Fixes

This section outlines the current state of test failures based on the most recent test logs analysis (from `docs/guardian_relationship_refactor_plan.md` and `docs/minitest_fixing_log.md`).

### Current System Test Status

*   **[❌] System Test Environment - Connection Issues**
    *   Connection timeouts and pending connections still affect overall system test suite stability.
    *   Browser/environment configuration issues need ongoing investigation.

*   **[x] Authentication Helper Consolidation - COMPLETE**
    *   Successfully refactored authentication helpers to improve reliability and reduce duplication.
    *   Created shared `AuthenticationCore` module for consistent authentication across test types.
    *   Fixed critical bugs with session leakage and header handling.
    *   Enhanced sign-in form field detection with progressive form selection.

*   **Passing (✅) System Tests:**
    *   `test/system/admin/paper_application_conditional_ui_test.rb`
    *   `test/system/admin/paper_application_rejection_test.rb` 
    *   `test/system/admin/paper_application_constituent_type_test.rb`
    *   `test/system/admin/application_audit_log_test.rb`
    *   `test/system/admin/guardian_proof_review_test.rb`
    *   `test/system/constituent_portal/application_show_test.rb`
    *   `test/system/constituent_portal/dependent_selection_test.rb`

*   **Failing (❌) System Tests - Priority Items:**
    *   `test/system/admin/paper_application_upload_test.rb` (Issues with fieldset elements, radio button selection)
    *   `test/system/constituent_portal/application_type_test.rb` (Unable to find checkbox "I certify that I am a resident of Maryland")
    *   `test/system/constituent_portal/applications_test.rb` (Unable to find checkbox "I am applying on behalf of someone under 18")
    *   `test/system/admin_guardian_management_test.rb` (Issues with guardian selection container, relationship mapping)
    *   `test/system/admin/paper_applications_test.rb` (Issues with fieldset legends, Stimulus hooks, income threshold warning)

*   **[x] Factory/Fixture Updates - COMPLETE**
    *   Updated factories with new traits for guardian/dependent relationships
    *   Fixed phone number uniqueness issues by using different prefixes
    *   Added GuardianRelationship factory

*   **[x] Missing Helper Methods - COMPLETE**
    *   Added missing `with_mocked_attachments` to `AttachmentTestHelper`
    *   Added missing `assert_mailbox_routed` to `ActionMailboxTestHelper`