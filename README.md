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
- ✅ VendorPortal namespace implementation (fixed controller namespace conflict)
- ✅ Email/letter correspondence templates with PDF generation
- ✅ Inbound email processing (via Action Mailbox)
- ⏳ Document OCR processing (planned)
- ⏳ Enhanced reporting system (partial)

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

## Documentation

- [Inbound Email Processing Guide](doc/inbound_email_processing_guide.md) - Setup and usage of email-based proof submission
- [Email/Letter Consistency](doc/email_letter_consistency.md) - Guidelines for maintaining consistent communication
- [Constituent Type Standardization](doc/constituent_type_standardization.md) - Standards for constituent type handling
- [Proof Attachment Guide](doc/proof_attachment_comprehensive_guide.md) - Complete guide to the proof attachment system
- [System Testing Chrome Update](doc/system_testing_chrome_update.md) - Notes on Chrome testing setup

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

## TODO

- [X] Complete API integration for Postmarkapp
- [X] Add admin page to change user role and assign role capabilities
- [X] Configure email templates
- [X] Implement letter generation and print queue system
- [X] Implement communication preference system (email/letter)
- [ ] Enhance admin dashboard views
- [ ] Enhance constituent dashboard view
- [ ] Add comprehensive application flow for constituents
- [ ] Implement document OCR processing via AWS
- [ ] Complete reporting system
- [ ] Enhance vendor transaction tracking
- [ ] Improve system tests coverage

## Acknowledgments

- Maryland Accessible Telecommunications Program
- Contributors and maintainers
