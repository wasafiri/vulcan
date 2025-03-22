# Vulcan: Maryland Accessible Telecommunications CRM

Vulcan is a Ruby on Rails application that facilitates Maryland Accessible Telecommunications (MAT) workflows. 

## Features

1. **Online Application Process**
   - Digital application submission
   - OCR import for scanned paper applications
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
   - Equipment distribution management
   - Inventory tracking

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

## Current Implementation Status

- ✅ Authentication system (using [authentication-zero](https://github.com/DiegoSalazar/rails-authentication-zero))
- ✅ Basic CRUD operations
- ✅ Core views and layouts
- ✅ Admin dashboard (basic implementation)
- ✅ Test data seeding
- ✅ User role management (Admin, Evaluator, Constituent, Vendor, Trainer, **Medical Provider** – though Medical Provider is now effectively hidden from the main user management UI)
- ✅ Role-capabilities system with Stimulus controllers for toggling capabilities
- ⏳ Postmark API integration for sending emails (migrated from ElasticEmail)
- ⏳ Enhanced vendor equipment management (partial)

## Technical Stack

- **Ruby** 3.3
- **Rails** 8.0
- **PostgreSQL**
- **Tailwind CSS**
- **Propshaft Asset Pipeline**
- **Solid Queue** (for background jobs)
- **Postmark** (for email delivery)
- **AWS S3** (planned for file storage and OCR functionality)

> **Note**: We **previously** planned on using ElasticEmail; we have now moved to **Postmark** for email.  
> We also decided **not** to use Pundit for authorization.

## Documentation

- [Inbound Email Processing Guide](doc/inbound_email_processing_guide.md) - Setup and usage of email-based proof submission

## Prerequisites

- Ruby 3.3.0 or higher
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
| Admin | admin@example.com | SecurePass123! |
| Evaluator | evaluator@example.com | SecurePass123! |
| Constituent | constituent@example.com | SecurePass123! |
| Vendor | vendor@example.com | SecurePass123! |
| Medical Provider | medical_provider@example.com | SecurePass123! |

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
- [ ] Configure email templates
- [ ] Enhance admin dashboard views
- [ ] Enhance constituent dashboard view
- [ ] Add comprehensive application flow for constituents
- [ ] Implement application upload and OCR processing via AWS
- [ ] Add page to add/remove devices supported by the program and/or available for new applicants to be assigned
- [ ] Implement reporting system
- [ ] Implement flow to reject document, send request for updated submission, display updated submission in admin dashboard
- [ ] Obtain alpha testing feedback

## Acknowledgments

- Maryland Accessible Telecommunications Program
- Contributors and maintainers
