# Vulcan: Maryland Accessible Telecommunications CRM

Vulcan is a Ruby on Rails application that facilitates Maryland Accessible Telecommunications (MAT) workflows. 

## Features

1. **Online Application Process**
   - Digital application submission with real-time validation
   - Paper application processing and uploads
   - Document upload and verification with multiple submission methods
   - Application status tracking with comprehensive audit trails
   - Guardian/dependent application management

2. **Guardian Relationship Management**
   - Guardian-dependent relationship establishment and tracking
   - Multi-user application workflows (guardians applying for dependents)
   - Comprehensive relationship validation and security controls
   - Admin interface for relationship management

3. **Medical Certification System**
   - Automated certification requests to medical providers
   - Multi-channel provider communication (email, fax)
   - Document upload and review workflows
   - Email delivery tracking with Postmark integration
   - Comprehensive audit trails and status tracking

4. **Proof Attachment System**
   - Unified document attachment service for all submission methods
   - Support for web uploads, email submissions, and faxed documents
   - Transaction-safe file operations with comprehensive error handling
   - Proof resubmission workflows with rate limiting
   - Automated metrics and failure monitoring

5. **Evaluation Management**
   - Scheduling and tracking evaluations
   - Training session management
   - Evaluator assignment and availability tracking
   - Documentation of evaluation outcomes

6. **Voucher System**
   - Secure voucher generation, assignment, and redemption
   - Vendor portal for redeeming vouchers and managing products
   - Automated invoice generation for vendor payments

7. **Program Policy Enforcement**
   - Automated eligibility checks with real-time validation
   - Waiting period enforcement
   - Training session limits
   - Income verification rules with FPL threshold validation

8. **Constituent Portal**
   - Application status checking with detailed progress tracking
   - Document submission and resubmission
   - Dependent management for guardians
   - Appointment scheduling
   - Profile management with audit logging

9. **Two-Factor Authentication**
   - WebAuthn (security keys, biometrics), TOTP, and SMS verification
   - Standardized session management built off of `authentication-zero` skeleton

10. **Unified Notification System**
    - Multi-channel delivery: Email, physical letters, SMS, and in-app alerts
    - Template-based generation for both emails and printable letters (PDF)
    - Centralized print queue management for batch processing
    - Delivery and open tracking with robust failure and bounce handling

11. **Advanced Admin Portal**
    - Comprehensive dashboard with real-time application pipeline metrics and charts
    - Fiscal year reporting for applications, vouchers, and vendor activity
    - Detailed, filterable views for all system entities
    - Secure interfaces for managing users, roles, and system policies

12. **Audit & Event System**
    - Comprehensive audit trails for every action taken by users and admins
    - Intelligent event deduplication to provide a clean, readable history
    - Centralized logging services for consistency and reliability
    - Full visibility into application status changes, communications, and reviews

## Current Implementation Status

- ✅ Authentication system (using Rails' built-in authentication)
- ✅ Two-factor authentication (WebAuthn, TOTP, SMS)
- ✅ Basic CRUD operations
- ✅ Core views and layouts
- ✅ Admin dashboard with reporting and charts
- ✅ Test data seeding
- ✅ User role management (Admin, Evaluator, Constituent, Vendor, Trainer, Medical Provider)
- ✅ Role-capabilities system with Stimulus controllers for toggling capabilities
- ✅ Guardian relationship management system
- ✅ Medical certification system with email tracking
- ✅ Proof attachment system with unified service architecture
- ✅ Postmark API integration for sending emails with delivery tracking
- ✅ Print queue system for letter generation and management
- ✅ Voucher management and redemption system
- ✅ Vendor W9 review process
- ✅ Vendor Portal implementation
- ✅ Email/letter correspondence templates with PDF generation
- ✅ Inbound email processing (via Action Mailbox)
- ✅ Communication preference system (email/letter)
- ✅ Enhanced vendor transaction tracking
- ✅ Real-time income threshold validation
- ✅ Comprehensive audit logging with intelligent event deduplication
- ⏳ Document OCR processing (planned)
- ⏳ Enhanced reporting system (in progress)

## Technical Stack

- **Ruby** 3.4.4
- **Rails** 8.0.2
- **PostgreSQL**
- **Tailwind CSS**
- **Propshaft Asset Pipeline**
- **Solid Queue** (for background jobs)
- **Postmark** (for email delivery)
- **Action Mailbox** (for inbound email processing)
- **AWS S3** (for file storage)
- **Twilio** (for SMS and fax services)

## Architecture

- **Service-Oriented Architecture**: Core business logic is encapsulated in dedicated service objects (e.g., `ProofAttachmentService`, `PaperApplicationService`) for clarity and testability.
- **Stimulus & Utility Services**: The front-end is powered by Stimulus controllers, supported by a suite of centralized JavaScript services for requests, charts, and UI events.
- **CurrentAttributes for Context**: Leverages Rails' `Current` object to safely manage request-specific state, such as paper application context, without polluting models or controllers.
- **Robust Testing Suite**: A comprehensive Minitest suite with custom helpers for authentication, attachment mocking, and context management ensures high reliability.

## Documentation

- [Application Workflow Guide](docs/features/application_workflow_guide.md) - High-level overview of all major application flows.
- [Proof Review Process Guide](docs/features/proof_review_process_guide.md) - Detailed guide to the proof submission, review, and approval lifecycle.
- [Guardian Relationship System](docs/development/guardian_relationship_system.md) - How guardian and dependent relationships are modeled and managed.
- [Paper Application Architecture](docs/development/paper_application_architecture.md) - Deep dive into the admin-facing paper application workflow.
- [Email System Guide](docs/infrastructure/email_system.md) - How inbound and outbound emails, templates, and letters work.
- [Voucher Security Controls](docs/security/voucher_security_controls.md) - Security measures for the voucher system.
- [Testing and Debugging Guide](docs/development/testing_and_debugging_guide.md) - Comprehensive guide for running and debugging the test suite.

## Prerequisites

- Ruby 3.4.4 or higher
- PostgreSQL 17 or higher
- Node.js v22 (LTS) or higher
- Yarn

## Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/yourusername/vulcan.git
   cd vulcan
   ```

2. Install dependencies:
   ```bash
   bundle install
   yarn install
   ```

3. Setup database:
   ```bash
   bin/rails db:create
   bin/rails db:migrate
   bin/rails db:seed
   ```

3a. Seed email templates:
   ```bash
   bin/rails db:seed:email_templates
   ```
   This command populates the `email_templates` table with the default email and letter templates used by the application.

4. Set up environment variables:
   ```bash
   cp config/application.yml.example config/application.yml
   # Edit application.yml with your credentials
   ```

5. Start the server:
   ```bash
   ./bin/dev # For development with hot-reloading
   bin/rails server
   ```

## Testing

The application uses Minitest for testing. To run the test suite:

```bash
bin/rails test
bin/rails test:system # For system tests
```

FactoryBot is used for test data generation. Factories can be found in `test/factories/`.

## Default Users

After seeding, the following test users are available:

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@example.com | password123 |
| Evaluator | evaluator@example.com | password123 |
| Constituent | user@example.com | password123 |
| Vendor | ray@testemail.com | password123 |
| Medical Provider | medical@example.com | password123 |

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE.md file for details.

## Acknowledgments

- Maryland Accessible Telecommunications Program
- Contributors and maintainers
