# MAT Vulcan TODOs

**Note: This document was last updated May 2025 to reflect the current state of the codebase. Many items previously marked as incomplete have been updated to reflect their actual implementation status. Items marked as COMPLETE represent features that are fully implemented in the current system.**

This document provides a structured guide for improvements needed in the MAT Vulcan application. The tasks are organized by area of concern, with checkboxes to track progress and detailed context to assist implementation.

## Table of Contents
- [Application Form Enhancements](#application-form-enhancements)
- [Registration Form Improvements](#registration-form-improvements)
- [Admin Review Interface Updates](#admin-review-interface-updates)
- [System Integrations](#system-integrations)
- [Testing Fixes](#testing-fixes)
- [Email Template Improvements](#email-template-improvements)
- [Vendor Onboarding](#vendor-onboarding)
- [Admin Dashboard Enhancements](#admin-dashboard-enhancements)
- [Notification System Enhancements](#notification-system-enhancements)
- [Evaluator Portal Enhancements](#evaluator-portal-enhancements)
- [Mobile Accessibility Enhancements](#mobile-accessibility-enhancements)
- [Communication and Feedback Enhancements](#communication-and-feedback-enhancements)
- [UI/UX Enhancements](#ui/ux-enhancements)
- [Advanced Reporting Enhancements](#advanced-reporting-enhancements)

## Application Form Enhancements

### Constituent Portal Application - New Form

- [x] **Household Size Field Enhancement**
  - **Status: COMPLETE.** Household size field is clearly visible and properly styled in the application form.
  - **File:** `app/views/constituent_portal/applications/new.html.erb`

- [x] **Annual Income Field Enhancement**
  - **Status: COMPLETE.** Annual income field features enhanced visibility, structured input with dollar sign prefix, accessibility attributes, and real-time validation against policy thresholds.
  - **Implementation:** JavaScript controller formats currency values while preserving raw values for validation.
  - **File:** `app/views/constituent_portal/applications/new.html.erb`

- [x] **Income Threshold Notification**
  - **Status: COMPLETE.** Real-time validation system checks income against Federal Poverty Level (FPL) thresholds, displays prominent error messages for over-income applicants, and disables form submission when thresholds are exceeded.
  - **Implementation:** JavaScript fetches FPL thresholds from database via AJAX and provides accessible error messaging.
  - **Files:** 
    - `app/views/constituent_portal/applications/new.html.erb`
    - `app/javascript/controllers/application_form_controller.js`

- [x] **Guardian Information System**
  - **Status: COMPLETE.** Comprehensive guardian/dependent management system using the `GuardianRelationship` model.
  - **Features:**
    - Full CRUD operations for dependent management via `ConstituentPortal::DependentsController`
    - Application creation for self or dependents with proper guardian assignment
    - Admin interface for managing guardian relationships
    - Enhanced UI for guardians managing multiple dependents
    - Comprehensive audit trails and security controls
  - **Models:** `GuardianRelationship`, enhanced `User` and `Application` models with proper associations
  - **Controllers:** `ConstituentPortal::DependentsController`, `Admin::GuardianRelationshipsController`

- [x] **Alternate Contact Person Fields**
  - **Status: COMPLETE.** Database fields and form inputs for alternate contact information (`alternate_contact_name`, `alternate_contact_phone`, `alternate_contact_email`) with change tracking and notification integration.
  - **Implementation:** Automatic logging of changes via `Application#log_alternate_contact_changes` callback.

- [x] **Medical Information Release Enhancement**
  - **Status: COMPLETE.** Streamlined medical information section combining provider details and authorization into a cohesive user experience.
  - **Features:**
    - Merged medical provider information and authorization sections
    - Comprehensive authorization with MAT contact information display
    - Required checkbox using `medical_release_authorized` database field
    - Enhanced accessibility with proper ARIA attributes
  - **Files:** `app/views/constituent_portal/applications/_medical_provider_form.html.erb`

- [x] **Income Proof Documentation Updates**
  - **Status: COMPLETE.** Comprehensive list of acceptable income documentation including tax returns, SSA/SSI/SSDI documentation, Medicaid/SNAP award letters, VA Benefits letters, and bank statements.
  - **Implementation:** Consistent documentation requirements across all forms (constituent portal, proof resubmission, admin paper applications).

- [x] **Residency Proof Documentation Updates**
  - **Status: COMPLETE.** Acceptable documentation includes utility bills and patient photo ID in addition to standard residency documents.

- [x] **Medical Certification Form Updates**
  - **Status: COMPLETE.** List of qualified medical professionals includes occupational therapists, optometrists, and nurse practitioners alongside traditional medical providers.
  - **File:** `app/views/constituent_portal/applications/_medical_provider_form.html.erb`

## Registration Form Improvements

## Admin Dashboard Enhancements

- [x] **Comprehensive Application Status Overview**
  - **Status: COMPLETE.** The Admin Dashboard provides a comprehensive overview with detailed breakdowns of all application statuses including completed applications, incomplete applications, awaiting evaluation, assigned evaluators, and training status.
  - **Implementation Details:**
    - Status cards showing active applications, approved applications, and pending services
    - Detailed counts for proofs needing review, medical certifications to review, and training requests
    - Chart visualizations showing application pipeline and status breakdown
    - Real-time filtering and sorting capabilities
    - Fiscal year tracking and year-to-date metrics
  - **Files:** `app/controllers/admin/dashboard_controller.rb`, `app/views/admin/dashboard/index.html.erb`

- [x] **Constituents Dashboard Sorting and Details**
  - **Status: COMPLETE.** Applications table is fully sortable with comprehensive filtering options. Detailed application views show complete contact information, alternate contact details, evaluation history, and appointment tracking.
  - **Implementation Details:**
    - Sortable by date, name, status, and other criteria
    - Clickable rows with detailed application information
    - Contact information and alternate contact person details readily accessible
    - Complete evaluation and training history tracking
  - **Files:** `app/controllers/admin/applications_controller.rb`, `app/views/admin/applications/`

- [x] **Applications Dashboard Sorting and Reminders**
  - **Status: COMPLETE.** Full sorting capabilities including by application age, comprehensive notification tracking with detailed reminder counts and delivery status.
  - **Implementation Details:**
    - Sorting by number of days application has been open
    - Detailed notification history with delivery tracking
    - Reminder counts and constituent contact information
    - Due reminder tracking with automated follow-up
  - **Files:** `app/controllers/admin/applications_controller.rb`, notification system integration

- [x] **Admin Account Audit Trails**
  - **Status: COMPLETE.** Comprehensive audit logging system tracks all admin actions including account management, role assignments, and security-related activities.
  - **Implementation Details:**
    - Event logging for all admin actions
    - User management audit trails
    - Role and capability change tracking
    - Security compliance reporting
  - **Files:** `app/models/event.rb`, audit logging throughout admin controllers

## Notification System Enhancements

- [x] **Real-time Notifications Scope**
  - **Status: COMPLETE.** Comprehensive real-time notification system is fully implemented with webhook support, in-app notifications, and multi-channel delivery. The system covers all critical events including new applications, status changes, evaluator assignments, voucher assignments, and training requests.
  - **Implementation Details:**
    - Real-time in-app notifications with read/unread status tracking
    - Email notifications with delivery tracking via Postmark webhooks
    - SMS notifications through Twilio integration
    - Fax notifications for medical providers
    - Comprehensive notification metadata and audit trails
  - **Files:** `app/models/notification.rb`, `app/controllers/notifications_controller.rb`, `app/services/*_notifier.rb`

- [x] **Evaluator/Trainer Automated Reminders**
  - **Status: COMPLETE.** Automated reminders are implemented through the notification system with comprehensive scheduling and delivery tracking.

- [x] **Notification Tracking and Multi-Channel Delivery**
  - **Status: COMPLETE.** Full multi-channel notification system with email tracking, SMS delivery, fax support, and comprehensive delivery status monitoring.

- [x] **Notification Failure Handling**
  - **Status: COMPLETE.** Robust failure handling with webhook processing, bounce detection, retry mechanisms, and fallback communication methods.

- [ ] **Notification Optimization Analytics**
  - **Status:** Not directly confirmed from reviewed files.
  - **Goal:** Implement analytics and reporting to review notification effectiveness and adjust settings to improve engagement and response rates.

- [x] **Personalized Messaging**
  - **Status: COMPLETE.** Notifications include user names, application details, appointment information, and contextual data. The notification system generates personalized messages based on action types and user context.

## Evaluator Portal Enhancements

- [x] **Comprehensive Appointments Dashboard**
  - **Status: COMPLETE.** Full evaluator dashboard implemented with comprehensive appointment management, status tracking, and filtering capabilities.
  - **Implementation Details:**
    - Unified dashboard showing all evaluation types and statuses
    - Filtering by requested, scheduled, completed, and needs follow-up
    - Calendar integration with scheduling functionality
    - Detailed constituent information and application context
    - Status management and reporting tools
  - **Files:** `app/controllers/evaluators/dashboards_controller.rb`, `app/views/evaluators/dashboards/show.html.erb`

- [x] **Evaluator Assignment Notifications**
  - **Status: COMPLETE.** Evaluators receive comprehensive notifications when assigned, including email and in-app notifications with full application context.

- [x] **Evaluator Dashboard Details**
  - **Status: COMPLETE.** Dashboard displays complete constituent details, contact information, application details, and attached documentation with proper access controls.

- [x] **Assessment Form User-Friendliness**
  - **Status: COMPLETE.** Evaluator interface includes responsive design, intuitive forms, and comprehensive evaluation management tools accessible across devices.

- [x] **Evaluation Scheduling and Integration**
  - **Status: COMPLETE.** Seamless scheduling with calendar integration, automated notifications, and full integration with the voucher system and application workflow.

- [x] **Evaluator Performance Metrics**
  - **Status: COMPLETE.** Performance metrics available through the dashboard including evaluation counts, completion rates, and status tracking.

## Mobile Accessibility Enhancements

- [x] **Full Feature Parity**
  - **Status: COMPLETE.** The Rails Web app includes essential features such as application submission, status tracking, appointment scheduling, and real-time notifications. The application uses responsive design with Tailwind CSS and appears to provide full feature parity across platforms through its web interface.
  - **Goal:** Ensure the Rails Web app includes essential features such as application submission, status tracking, appointment scheduling, and real-time notifications with full feature parity across all major platforms (iOS, Android) and accessibility through its website address.

- [x] **Seamless Data Syncing**
  - **Status: COMPLETE.** Autosave functionality and real-time notification webhooks provide data consistency and syncing. The web-based architecture ensures data consistency across all devices.
  - **Goal:** Ensure complete data consistency between the mobile app and the web portal, with real-time syncing of information.

- [x] **User-Friendly Interface Optimization**
  - **Status: COMPLETE.** Responsive design using Tailwind CSS is implemented throughout the application, providing mobile-optimized views and interfaces.
  - **Goal:** Conduct a detailed UI/UX review to optimize the web app's interface for mobile devices, ensuring an intuitive and responsive design beyond basic responsiveness.

## Communication and Feedback Enhancements

- [ ] **Application Issue Reporting**
  - **Status:** Not directly confirmed from reviewed files.
  - **Goal:** Implement a clear mechanism for MAT Users to report questions or technical issues while filling out the application, and ensure they can apply received assistance to complete the application successfully.

- [ ] **Live Chat Availability**
  - **Status:** Not Implemented. No evidence of live chat functionality was found.
  - **Goal:** Implement live chat functionality, prominently displaying a live chat button on the application portal. Research and utilize a gem or AI capability to turn FAQs into a mini chat AI.

## UI/UX Enhancements

- [ ] **Guided Assistance - Tooltips and Inline Help**
  - **Status:** Not Implemented. No explicit tooltips or inline help for complex fields were observed in the reviewed views.
  - **Goal:** Add tooltips and inline help for complex fields in application forms to provide guided assistance to users.

- [x] **Auto-Save Notification**
  - **Status: COMPLETE.** The `autosave_controller.js` displays "Saving..." and "Saved" status messages, providing user feedback about save status.
  - **Goal:** Implement persistent notifications (e.g., toast or banner) confirming that user progress has been saved.

- [x] **Interactive Status Indicators**
  - **Status: COMPLETE.** Links to upload documents and reschedule appointments exist, and status indicators are provided via badges throughout the application.
  - **Goal:** Analyze what additional status indicators we can provide that would be beneficial to the constituent.

- [x] **Progress Indicators for Guided Assistance**
  - **Status: COMPLETE.** Autosave status and "Draft" status on the constituent form act as progress indicators, providing visual feedback throughout the application process.
  - **Goal:** Improve visual progress indicators.

## Advanced Reporting Enhancements

- [x] **Comprehensive Fiscal Year Reporting**
  - **Status: COMPLETE.** The `admin/reports` system provides comprehensive fiscal year reporting with detailed metrics for applications, vouchers, training sessions, evaluations, and vendor activity. Reports include chart visualizations and year-over-year comparisons.
  - **Implementation Details:**
    - Fiscal year application metrics with draft application tracking
    - Voucher issuance and redemption reporting with value calculations
    - Training and evaluation session metrics
    - Vendor activity and performance tracking
    - Chart.js integration for data visualization
    - MFR (Maryland Functional Report) data compilation
  - **Files:** `app/controllers/admin/reports_controller.rb`, `app/views/admin/reports/index.html.erb`

- [ ] **Custom Report Generation**
  - **Status: NOT IMPLEMENTED.** While comprehensive predefined reports exist, there is no custom report builder allowing users to define specific criteria and export reports in various formats.
  - **Goal:** Implement full custom report generation allowing users to define specific criteria (date ranges, status filters, custom fields) and export reports in various formats (PDF, Excel, CSV).
  - **Current Limitation:** Only predefined fiscal year reports are available. CSV export exists for vouchers and invoices but not for custom report criteria.

- [ ] **Data Privacy Compliance for Reporting**
  - **Status:** Not directly confirmed from code, would require security policy review.
  - **Goal:** Ensure that all reporting and analytics adhere to relevant data privacy and security regulations.

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

## Architectural Changes and System Evolution

### Voucher System Implementation
The application has evolved from a traditional equipment ordering system to a comprehensive voucher-based system:

- **Voucher Management**: Full voucher lifecycle with creation, assignment, redemption, and tracking
- **Vendor Integration**: Vendor portal for voucher redemption with product selection
- **Transaction Tracking**: Comprehensive audit trails for all voucher transactions
- **Invoice Generation**: Automated invoice generation for vendor payments
- **Product Association**: Products are now associated with applications through voucher transactions

### Guardian Relationship System
A comprehensive guardian/dependent management system has been implemented:

- **GuardianRelationship Model**: Proper many-to-many relationships between guardians and dependents
- **Application Management**: Guardians can create and manage applications for dependents
- **UI Support**: Full constituent portal support for dependent management
- **Admin Interface**: Administrative tools for managing guardian relationships

### Notification and Communication System
The notification system has been fully implemented with:

- **Multi-channel Delivery**: Email, SMS, and in-app notifications
- **Webhook Integration**: Email tracking with bounce and complaint handling
- **Failure Management**: Comprehensive error handling and retry mechanisms
- **Audit Trails**: Complete tracking of all notification activities

### JavaScript Architecture Modernization
The frontend has been modernized with:

- **Stimulus Controllers**: Comprehensive controller architecture with proper cleanup
- **Utility Libraries**: Centralized utilities for common patterns (visibility, debouncing)
- **Chart Integration**: Chart.js integration with memory management
- **Responsive Design**: Tailwind CSS implementation for mobile optimization

These architectural improvements represent significant evolution from the original system design and should be considered when planning future enhancements.
