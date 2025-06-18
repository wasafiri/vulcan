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

6. **Equipment Management**
   - Vendor equipment catalog
   - Order processing and tracking
   - Voucher generation and redemption
   - Equipment distribution management

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
   - WebAuthn support (security keys, biometrics)
   - TOTP authenticator app integration
   - SMS verification
   - Standardized session management

10. **Print System**
    - Letter generation for various notifications
    - Print queue management
    - Batch PDF downloads

11. **Email System**
    - Template-based email generation
    - Delivery tracking and status monitoring
    - Multi-stream message routing
    - Inbound email processing

## Current Implementation Status

- ✅ Authentication system (using [authentication-zero](https://github.com/DiegoSalazar/rails-authentication-zero))
- ✅ Two-factor authentication (WebAuthn, TOTP, SMS)
- ✅ Basic CRUD operations
- ✅ Core views and layouts
- ✅ Admin dashboard
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
- ✅ Comprehensive audit logging and event tracking
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
- **Twilio** (for fax services)

## Documentation

### Core Functionality
- [Inbound Email Processing Guide](docs/inbound_email_processing_guide.md) - Setup and usage of email-based proof submission
- [Email/Letter Template Management](docs/mailer_template_management.md) - Documentation on the database email template and letter generation system
- [Constituent Type Standardization](docs/constituent_type_standardization.md) - Standards for constituent type handling

### Proof System
- [Proof Attachment Guide](docs/proof_attachment_guide.md) - Comprehensive guide to the proof attachment system including submission, resubmission, monitoring, and improvements

### Medical Certification
- [Medical Certification Guide](docs/medical_certification_guide.md) - Complete guide to the medical certification process including requesting, approving, and rejecting certifications

### System Configuration
- [System Testing Guide](docs/system_testing_guide.md) - Comprehensive guide to system testing with Chrome and Selenium
- [Paper Application File Uploads](docs/paper_application_file_uploads.md) - Paper application processing
- [Email Delivery Tracking](docs/email_delivery_tracking.md) - Email delivery monitoring

## Prerequisites

- Ruby 3.4.4 or higher
- PostgreSQL 14 or higher
- Node.js 18 or higher
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
   bin/rails server
   ```

## Testing

The application uses Minitest for testing. To run the test suite:

```bash
bin/rails test
```

FactoryBot is used for test data generation. Factories can be found in `test/factories/`.

## Default Users

After seeding, the following test users are available:

| Role | Email | Password |
|------|-------|----------|
| Admin | admin@example.com | password123 |
| Evaluator | evaluator@example.com | password123 |
| Constituent | user@example.com | password123 |
| Vendor | raz@testemail.com | password123 |
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
