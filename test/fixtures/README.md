# Test Fixtures

This directory contains fixture data used for testing purposes. This document outlines the structure, dependencies, and naming conventions to help developers understand how fixtures are organized and how they should be used.

## General Guidelines

- **When to use fixtures**: Use fixtures for simple, static lookup data that doesn't change between tests.
- **When to use factories**: Use FactoryBot factories (in `test/factories/`) for models with complex associations, validations, or varying states.

## Key Dependencies Between Fixtures

### Users → Applications

- Applications depend on users through the `user` attribute (e.g., `application.user: confirmed_user`).
- Users of different types (`Users::Administrator`, `Users::Constituent`, etc.) are referenced by applications for different purposes.

### Applications → Evaluations

- Evaluations depend on applications through the `application_id` attribute.
- An evaluation is typically associated with a specific application.

### Applications → Vouchers

- Vouchers depend on applications through the `application_id` attribute.
- Vouchers represent approved benefits tied to a specific application.

### Users → Evaluations

- Evaluations may be associated with both a constituent (the applicant) and an evaluator (the person performing the evaluation).

## Naming Conventions

- Use descriptive names that indicate the purpose or state of the fixture (e.g., `active`, `approved`, `rejected`).
- For fixtures with similar purposes but different states, use consistent prefixes (e.g., `in_progress_with_approved_proofs`, `in_progress_with_rejected_proofs`).
- For user fixtures, indicate the type or role (e.g., `admin_david`, `constituent_john`).

## Special Considerations

### ActiveStorage Attachments

- Fixtures for models with ActiveStorage attachments (like `Application`) might not include the attachment references directly.
- For testing with attachments, consider using factories with the `:with_mocked_income_proof`, `:with_real_income_proof`, etc. traits.

### STI (Single Table Inheritance)

- User fixtures use the `type` attribute to determine the specific class (e.g., `Users::Administrator`, `Users::Constituent`).
- Ensure the `type` value matches a valid class name.

## Recommended Approach

1. For simple tests with static data, use fixtures.
2. For complex models or scenarios, especially those involving validations, callbacks, or varying states, use factories.
3. When creating new tests, prefer factories over fixtures for better isolation and improved readability.
