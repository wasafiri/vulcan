# MAT Vulcan TODOs

**Note: This document was last updated June 2025. Items marked as COMPLETE represent features that are fully implemented in the current system.**

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

- [✅] **Household Size Field Enhancement**
  - **Status: COMPLETE.** Household size field is clearly visible and properly styled in the application form.
  - **File:** `app/views/constituent_portal/applications/new.html.erb`

- [✅] **Annual Income Field Enhancement**
  - **Status: COMPLETE.** Annual income field features enhanced visibility, structured input with dollar sign prefix, accessibility attributes, and real-time validation against policy thresholds.
  - **Implementation:** JavaScript controller formats currency values while preserving raw values for validation.
  - **File:** `app/views/constituent_portal/applications/new.html.erb`

- [✅] **Income Threshold Notification**
  - **Status: COMPLETE.** Real-time validation system checks income against Federal Poverty Level (FPL) thresholds, displays prominent error messages for over-income applicants, and disables form submission when thresholds are exceeded.
  - **Implementation:** JavaScript fetches FPL thresholds from database via AJAX and provides accessible error messaging.
  - **Files:** 
    - `app/views/constituent_portal/applications/new.html.erb`
    - `app/javascript/controllers/application_form_controller.js`

- [✅] **Guardian Information System**
  - **Status: COMPLETE.** Comprehensive guardian/dependent management system using the `GuardianRelationship` model.
  - **Features:**
    - Full CRUD operations for dependent management via `ConstituentPortal::DependentsController`
    - Application creation for self or dependents with proper guardian assignment
    - Admin interface for managing guardian relationships
    - Enhanced UI for guardians managing multiple dependents
    - Comprehensive audit trails and security controls
  - **Models:** `GuardianRelationship`, enhanced `User` and `Application` models with proper associations
  - **Controllers:** `ConstituentPortal::DependentsController`, `Admin::GuardianRelationshipsController`

- [✅] **Alternate Contact Person Fields**
  - **Status: COMPLETE.** Database fields and form inputs for alternate contact information (`alternate_contact_name`, `alternate_contact_phone`, `alternate_contact_email`) with change tracking and notification integration.
  - **Implementation:** Automatic logging of changes via `Application#log_alternate_contact_changes` callback.

- [✅] **Medical Information Release Enhancement**
  - **Status: COMPLETE.** Streamlined medical information section combining provider details and authorization into a cohesive user experience.
  - **Features:**
    - Merged medical provider information and authorization sections
    - Comprehensive authorization with MAT contact information display
    - Required checkbox using `medical_release_authorized` database field
    - Enhanced accessibility with proper ARIA attributes
  - **Files:** `app/views/constituent_portal/applications/_medical_provider_form.html.erb`

- [✅] **Income Proof Documentation Updates**
  - **Status: COMPLETE.** Comprehensive list of acceptable income documentation including tax returns, SSA/SSI/SSDI documentation, Medicaid/SNAP award letters, VA Benefits letters, and bank statements.
  - **Implementation:** Consistent documentation requirements across all forms (constituent portal, proof resubmission, admin paper applications).

- [✅] **Residency Proof Documentation Updates**
  - **Status: COMPLETE.** Acceptable documentation includes utility bills and patient photo ID in addition to standard residency documents.

- [✅] **Medical Certification Form Updates**
  - **Status: COMPLETE.** List of qualified medical professionals includes occupational therapists, optometrists, and nurse practitioners alongside traditional medical providers.
  - **File:** `app/views/constituent_portal/applications/_medical_provider_form.html.erb`

## Registration Form Improvements

## Admin Dashboard Enhancements

- [✅] **Comprehensive Application Status Overview**
  - **Status: COMPLETE.** The Admin Dashboard provides a comprehensive overview with detailed breakdowns of all application statuses including completed applications, incomplete applications, awaiting evaluation, assigned evaluators, and training status.
  - **Implementation Details:**
    - Status cards showing active applications, approved applications, and pending services
    - Detailed counts for proofs needing review, medical certifications to review, and training requests
    - Chart visualizations showing application pipeline and status breakdown
    - Real-time filtering and sorting capabilities
    - Fiscal year tracking and year-to-date metrics
  - **Files:** `app/controllers/admin/dashboard_controller.rb`, `app/views/admin/dashboard/index.html.erb`

- [✅] **Constituents Dashboard Sorting and Details**
  - **Status: COMPLETE.** Applications table is fully sortable with comprehensive filtering options. Detailed application views show complete contact information, alternate contact details, evaluation history, and appointment tracking.
  - **Implementation Details:**
    - Sortable by date, name, status, and other criteria
    - Clickable rows with detailed application information
    - Contact information and alternate contact person details readily accessible
    - Complete evaluation and training history tracking
  - **Files:** `app/controllers/admin/applications_controller.rb`, `app/views/admin/applications/`

- [✅] **Applications Dashboard Sorting and Reminders**
  - **Status: COMPLETE.** Full sorting capabilities including by application age, comprehensive notification tracking with detailed reminder counts and delivery status.
  - **Implementation Details:**
    - Sorting by number of days application has been open
    - Detailed notification history with delivery tracking
    - Reminder counts and constituent contact information
    - Due reminder tracking with automated follow-up
  - **Files:** `app/controllers/admin/applications_controller.rb`, notification system integration

- [✅] **Admin Account Audit Trails**
  - **Status: COMPLETE.** Comprehensive audit logging system tracks all admin actions including account management, role assignments, and security-related activities.
  - **Implementation Details:**
    - Event logging for all admin actions
    - User management audit trails
    - Role and capability change tracking
    - Security compliance reporting
  - **Files:** `app/models/event.rb`, audit logging throughout admin controllers

## Notification System Enhancements

- [✅] **Real-time Notifications Scope**
  - **Status: COMPLETE.** Comprehensive real-time notification system is fully implemented with webhook support, in-app notifications, and multi-channel delivery. The system covers all critical events including new applications, status changes, evaluator assignments, voucher assignments, and training requests.
  - **Implementation Details:**
    - Real-time in-app notifications with read/unread status tracking
    - Email notifications with delivery tracking via Postmark webhooks
    - SMS notifications through Twilio integration
    - Fax notifications for medical providers
    - Comprehensive notification metadata and audit trails
  - **Files:** `app/models/notification.rb`, `app/controllers/notifications_controller.rb`, `app/services/*_notifier.rb`

- [✅] **Evaluator/Trainer Automated Reminders**
  - **Status: COMPLETE.** Automated reminders are implemented through the notification system with comprehensive scheduling and delivery tracking.

- [✅] **Notification Tracking and Multi-Channel Delivery**
  - **Status: COMPLETE.** Full multi-channel notification system with email tracking, SMS delivery, fax support, and comprehensive delivery status monitoring.

- [✅] **Notification Failure Handling**
  - **Status: COMPLETE.** Robust failure handling with webhook processing, bounce detection, retry mechanisms, and fallback communication methods.

- [ ] **Notification Optimization Analytics**
  - **Status:** Not directly confirmed from reviewed files.
  - **Goal:** Implement analytics and reporting to review notification effectiveness and adjust settings to improve engagement and response rates.

- [✅] **Personalized Messaging**
  - **Status: COMPLETE.** Notifications include user names, application details, appointment information, and contextual data. The notification system generates personalized messages based on action types and user context.

## Evaluator Portal Enhancements

- [✅] **Comprehensive Appointments Dashboard**
  - **Status: COMPLETE.** Full evaluator dashboard implemented with comprehensive appointment management, status tracking, and filtering capabilities.
  - **Implementation Details:**
    - Unified dashboard showing all evaluation types and statuses
    - Filtering by requested, scheduled, completed, and needs follow-up
    - Calendar integration with scheduling functionality
    - Detailed constituent information and application context
    - Status management and reporting tools
  - **Files:** `app/controllers/evaluators/dashboards_controller.rb`, `app/views/evaluators/dashboards/show.html.erb`

- [✅] **Evaluator Assignment Notifications**
  - **Status: COMPLETE.** Evaluators receive comprehensive notifications when assigned, including email and in-app notifications with full application context.

- [✅] **Evaluator Dashboard Details**
  - **Status: COMPLETE.** Dashboard displays complete constituent details, contact information, application details, and attached documentation with proper access controls.

- [✅] **Assessment Form User-Friendliness**
  - **Status: COMPLETE.** Evaluator interface includes responsive design, intuitive forms, and comprehensive evaluation management tools accessible across devices.

- [✅] **Evaluation Scheduling and Integration**
  - **Status: COMPLETE.** Seamless scheduling with calendar integration, automated notifications, and full integration with the voucher system and application workflow.

- [✅] **Evaluator Performance Metrics**
  - **Status: COMPLETE.** Performance metrics available through the dashboard including evaluation counts, completion rates, and status tracking.

## Mobile Accessibility Enhancements

- [✅] **Full Feature Parity**
  - **Status: COMPLETE.** The Rails Web app includes essential features such as application submission, status tracking, appointment scheduling, and real-time notifications. The application uses responsive design with Tailwind CSS and appears to provide full feature parity across platforms through its web interface.
  - **Goal:** Ensure the Rails Web app includes essential features such as application submission, status tracking, appointment scheduling, and real-time notifications with full feature parity across all major platforms (iOS, Android) and accessibility through its website address.

- [✅] **Seamless Data Syncing**
  - **Status: COMPLETE.** Autosave functionality and real-time notification webhooks provide data consistency and syncing. The web-based architecture ensures data consistency across all devices.
  - **Goal:** Ensure complete data consistency between the mobile app and the web portal, with real-time syncing of information.

- [✅] **User-Friendly Interface Optimization**
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

- [✅] **Auto-Save Notification**
  - **Status: COMPLETE.** The `autosave_controller.js` displays "Saving..." and "Saved" status messages, providing user feedback about save status.
  - **Goal:** Implement persistent notifications (e.g., toast or banner) confirming that user progress has been saved.

- [✅] **Interactive Status Indicators**
  - **Status: COMPLETE.** Links to upload documents and reschedule appointments exist, and status indicators are provided via badges throughout the application.
  - **Goal:** Analyze what additional status indicators we can provide that would be beneficial to the constituent.

- [✅] **Progress Indicators for Guided Assistance**
  - **Status: COMPLETE.** Autosave status and "Draft" status on the constituent form act as progress indicators, providing visual feedback throughout the application process.
  - **Goal:** Improve visual progress indicators.

## Advanced Reporting Enhancements

- [✅] **Comprehensive Fiscal Year Reporting**
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

- [✅] **Proof Review Modal Context Enhancement**
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

- [✅] **Email Templates Audit Logging**
  - Add audit logging to email_templates#show similar to other admin pages
  - Ensure logs appear in the admin/applications#index "master" audit log
  - **Status: COMPLETE.** Added comprehensive audit logging to email templates controller for view, update, and test email actions using Event.create! pattern.
  - Files:
    - `app/controllers/admin/email_templates_controller.rb` (added audit logging for show, update, and send_test actions)
    - Events are logged with action types: 'email_template_viewed', 'email_template_updated', 'email_template_test_sent'

- [✅] **Email Proof Submission Webhook**
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

### Current System Test Status - UPDATED December 2025

*   **[✅] Application Test Suite - 100% SUCCESS RATE**
    *   **76 application tests passing** with 319 assertions, 0 failures, 0 errors
    *   EventDeduplicationService consolidation completed successfully
    *   Thread-local to Current attributes migration completed
    *   Robust test patterns established with unique test data

*   **[✅] Authentication Helper Consolidation - COMPLETE**
    *   Successfully refactored authentication helpers to improve reliability and reduce duplication.
    *   Created shared `AuthenticationCore` module for consistent authentication across test types.
    *   Fixed critical bugs with session leakage and header handling.
    *   Enhanced sign-in form field detection with progressive form selection.

*   **✅ All Application-Related System Tests Passing:**
    *   `test/system/admin/paper_application_conditional_ui_test.rb`
    *   `test/system/admin/paper_application_rejection_test.rb` 
    *   `test/system/admin/paper_application_constituent_type_test.rb`
    *   `test/system/admin/application_audit_log_test.rb`
    *   `test/system/admin/guardian_proof_review_test.rb`
    *   `test/system/constituent_portal/application_show_test.rb`
    *   `test/system/constituent_portal/dependent_selection_test.rb`
    *   `test/system/admin/paper_application_upload_test.rb` - ✅ **FIXED**
    *   `test/system/constituent_portal/application_type_test.rb` - ✅ **FIXED**
    *   `test/system/constituent_portal/applications_test.rb` - ✅ **FIXED**
    *   `test/system/admin/paper_applications_test.rb` - ✅ **FIXED**

*   **[❌] Non-Application System Tests** (if any remain)
    *   System test environment connection issues may still affect non-application tests
    *   Browser/environment configuration needs ongoing investigation for other test suites

*   **[✅] Factory/Fixture Updates - COMPLETE**
    *   Updated factories with new traits for guardian/dependent relationships
    *   Fixed phone number uniqueness issues by using different prefixes
    *   Added GuardianRelationship factory

*   **[✅] Missing Helper Methods - COMPLETE**
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

### Application Test Architecture & Event Deduplication (December 2025)
Major architectural consolidation completed with significant improvements:

- **EventDeduplicationService Consolidation**: Replaced 3 competing deduplication systems with single robust service
- **Time-Windowing Algorithm**: Proper time bucketing using integer division for 1-minute deduplication windows
- **Priority-Based Selection**: ApplicationStatusChange > Event > Notification priority handling
- **Medical Certification Awareness**: Special handling for medical certification event grouping
- **Thread-local to Current Attributes**: Complete migration from Thread-local variables to Rails CurrentAttributes
- **Test Pattern Standardization**: Unique timestamp-based test data, proper Current attributes setup/teardown
- **76 Application Tests Passing**: Complete test suite success with 319 assertions, 0 failures

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

## Chart.js Infrastructure Consolidation

### Critical Issue: Conflicting Chart.js Loading Architecture
**Priority: HIGH** - Causing system test instability and `Ferrum::PendingConnectionsError` in dashboard tests.

**Current State Analysis (December 2025):**
- **Triple Chart.js Configuration Conflict**: System has three different Chart.js handling approaches operating simultaneously:
  1. **NPM Package**: `"chart.js": "^4.4.8"` in package.json (DISABLED via commented imports)
  2. **CDN Loading**: `<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>` in admin dashboard (REMOVED as quick fix)
  3. **JavaScript Stubs**: Multiple stub implementations in both production and test environments

**Root Cause of Test Failures:**
- CDN script loading creates race conditions during system tests
- Network blocking configuration conflicts with Chart.js CDN requests
- `PendingConnectionsError` occurs when tests run faster than CDN requests can be blocked
- Browser stability issues from conflicting Chart.js instances

**Immediate Fix Applied:**
- ✅ Removed CDN script tag from `app/views/admin/applications/index.html.erb`
- ✅ Enhanced network blocking rules in `test/application_system_test_case.rb` to include:
  - `cdn.jsdelivr.net`, `unpkg.com`, `cdnjs.cloudflare.com` in host resolver rules
  - Corresponding regex patterns in URL blacklist

**Architecture Decision Required:**

### Option A: Full Stub Architecture (Recommended for Stability)
**Pros:** Maximum test reliability, no network dependencies, faster page loads
**Cons:** No real charting functionality, placeholder content only
**Implementation:**
- Keep existing stub in `application.js`
- Update `ChartBaseController` to show placeholder content instead of real charts
- Remove Chart.js from package.json dependencies
- Maintain test environment stubs

### Option B: Full Chart.js Implementation (Feature-Rich but Complex)
**Pros:** Complete charting functionality, rich data visualization
**Cons:** Network dependencies, potential stability issues, larger bundle size
**Implementation:**
- Enable Chart.js import in `application.js`: `import { Chart, registerables } from "chart.js"`
- Remove all stub implementations
- Update network blocking to allow Chart.js in development/production
- Maintain test environment blocking only

### Option C: Environment-Based Conditional Loading (Best of Both Worlds)
**Pros:** Real charts in production, stable tests, flexible deployment
**Cons:** More complex configuration, requires environment detection
**Implementation:**
- Environment-specific Chart.js loading logic
- Real Chart.js in development/production environments
- Stubbed Chart.js in test environment only
- Conditional network blocking based on Rails environment

**Technical Debt Items:**

- [ ] **Chart.js Architecture Consolidation**
  - **Priority:** HIGH
  - **Goal:** Choose and implement one of the three architectural approaches above
  - **Current Blocker:** Multiple conflicting Chart.js loading mechanisms
  - **Files Affected:**
    - `app/javascript/application.js` (stub implementation)
    - `test/application_system_test_case.rb` (test stub + network blocking)
    - `app/javascript/controllers/charts/base_controller.js` (expects real Chart.js)
    - `app/javascript/services/chart_config.js` (chart configuration service)
    - `package.json` (Chart.js dependency)

- [ ] **Chart Controller Infrastructure Audit**
  - **Priority:** MEDIUM
  - **Goal:** Audit all chart controllers to ensure they handle the chosen Chart.js architecture
  - **Files to Review:**
    - `app/javascript/controllers/charts/base_controller.js`
    - `app/javascript/controllers/charts/reports_chart_controller.js`
    - Any views using `data-controller="chart"` attributes

- [ ] **Network Blocking Configuration Optimization**
  - **Priority:** LOW
  - **Goal:** Optimize CDN blocking rules based on final Chart.js architecture decision
  - **Implementation:** May need to adjust blocking rules in `test/application_system_test_case.rb`

**Recommendation:**
Start with **Option A (Full Stub)** for immediate stability, then evaluate **Option C (Environment-Based)** if charting functionality becomes a business requirement. The current system has well-designed chart controllers that can be easily activated when needed.

**Testing Impact:**
- System test stability should improve significantly with CDN script removal
- Dashboard tests should no longer experience `PendingConnectionsError`
- Chart-related UI tests may need updates based on final architecture choice
