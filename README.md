# Vulcan: Maryland Accessible Telecommunications CRM

Vulcan is a Ruby on Rails application that facilitates Maryland Accessible Telecommunications (MAT) workflows. 

## Features

1. **Online Application Process**
   - Digital application submission
   - Paper application processing and uploads
   - Document upload and verification
   - Application status tracking

2. **Evaluation Management**
   - Scheduling and tracking evaluations
   - Training session management
   - Evaluator assignment and availability tracking
   - Documentation of evaluation outcomes

3. **Equipment Management**
   - Vendor equipment catalog
   - Order processing and tracking
   - Voucher generation and redemption
   - Equipment distribution management

4. **Program Policy Enforcement**
   - Automated eligibility checks
   - Waiting period enforcement
   - Training session limits
   - Income verification rules

5. **Constituent Portal**
   - Application status checking
   - Document submission
   - Appointment scheduling
   - Profile management

6. **Print System**
   - Letter generation for various notifications
   - Print queue management
   - Batch PDF downloads

## Current Implementation Status

- ✅ Authentication system (using [authentication-zero](https://github.com/DiegoSalazar/rails-authentication-zero))
- ✅ Basic CRUD operations
- ✅ Core views and layouts
- ✅ Admin dashboard
- ✅ Test data seeding
- ✅ User role management (Admin, Evaluator, Constituent, Vendor, Trainer, Medical Provider)
- ✅ Role-capabilities system with Stimulus controllers for toggling capabilities
- ✅ Postmark API integration for sending emails
- ✅ Print queue system for letter generation and management
- ✅ Voucher management and redemption system
- ✅ Vendor W9 review process
- ✅ Vendor Portal implementation
- ✅ Email/letter correspondence templates with PDF generation
- ✅ Inbound email processing (via Action Mailbox)
- ✅ Communication preference system (email/letter)
- ✅ Enhanced vendor transaction tracking
- ⏳ Document OCR processing (planned)
- ⏳ Enhanced reporting system (in progress)

## Technical Stack

- **Ruby** 3.4.2
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
- [Inbound Email Processing Guide](doc/inbound_email_processing_guide.md) - Setup and usage of email-based proof submission
- [Email/Letter Consistency](doc/email_letter_consistency.md) - Guidelines for maintaining consistent communication
- [Constituent Type Standardization](doc/constituent_type_standardization.md) - Standards for constituent type handling

### Proof System
- [Proof Attachment Guide](doc/proof_attachment_guide.md) - Comprehensive guide to the proof attachment system including submission, resubmission, monitoring, and improvements

### Medical Certification
- [Medical Certification Guide](doc/medical_certification_guide.md) - Complete guide to the medical certification process including requesting, approving, and rejecting certifications

### System Configuration
- [System Testing Guide](doc/system_testing_guide.md) - Comprehensive guide to system testing with Chrome and Selenium
- [Paper Application File Uploads](doc/paper_application_file_uploads.md) - Paper application processing
- [Email Delivery Tracking](doc/email_delivery_tracking.md) - Email delivery monitoring

## Prerequisites

- Ruby 3.4.2 or higher
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
