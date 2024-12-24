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

- ✅ Authentication system (using authentication-zero)
- ✅ Basic CRUD operations
- ✅ Core views and layouts
- ✅ Admin dashboard (basic implementation)
- ✅ Test data seeding
- ✅ User role management (Admin, Evaluator, Constituent, Vendor, Medical Provider)

## Technical Stack

- Ruby 3.3
- Rails 8.0
- PostgreSQL
- Tailwind CSS
- Propshaft Asset Pipeline
- Solid Queue (for background jobs)
- ElasticEmail for email delivery
- AWS S3 for file storage and OCR functionality

## Prerequisites

- Ruby 3.3.0 or higher
- PostgreSQL 14 or higher
- Node.js 18 or higher
- Yarn

## Setup

1. Clone the repository:
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

- [ ] Complete API integration for ElasticEmail
- [ ] Configure email templates
- [ ] Enhance admin dashboard views
- [ ] Enhance constituent dashboard view
- [ ] Implement Pundit for authorization to go along with authentication-zero for authentication
- [ ] Add comprehensive application flow for constituents
- [ ] Implement application upload and OCR processing via AWS
- [ ] Add vendor equipment management dashboard
- [ ] Implement reporting system

## Acknowledgments

- Maryland Accessible Telecommunications Program
- Contributors and maintainers
