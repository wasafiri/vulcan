# User Signup Deduplication Guide

This document outlines the strategy implemented to prevent duplicate user accounts during registration in the MAT Vulcan application.

## Strategy Implemented

A two-pronged approach was implemented:

1.  **Strict Uniqueness on Phone Number:**
    *   A unique database index was added to the `phone` column in the `users` table (`index_users_on_phone`). This enforces uniqueness at the database level, preventing multiple users from having the same phone number (after normalization).
    *   The `User` model includes a validation (`validates :phone, uniqueness: ...`) to provide user-friendly errors if a duplicate phone number is entered during registration or update.
    *   Phone numbers are normalized (stripped of non-digits, leading '1' removed, formatted to XXX-XXX-XXXX) *before* validation using a `before_validation :format_phone_number` callback in the `User` model.

2.  **Soft Check for Name + Date of Birth (DOB) Duplicates:**
    *   Instead of blocking registration, users with matching `first_name`, `last_name` (case-insensitive), and `date_of_birth` are flagged for administrative review.
    *   A boolean column `needs_duplicate_review` was added to the `users` table (defaulting to `false`).
    *   The `RegistrationsController#create` action now performs a check (`potential_duplicate_found?`) after initializing the new user object but *before* saving.
    *   If a potential duplicate (matching name and DOB, but different email/phone) is found, the `needs_duplicate_review` flag on the new user record is set to `true`.
    *   The registration proceeds normally, but the flag allows administrators to identify and investigate potential duplicates later.

## Implementation Details

*   **Migrations:**
    *   `AddUniqueIndexToUsersPhone`: Added the unique index on the `phone` column.
    *   `AddNeedsDuplicateReviewToUsers`: Added the `needs_duplicate_review` boolean column.
*   **Models:**
    *   `app/models/user.rb`:
        *   Added `validates :phone, uniqueness: ...`.
        *   Ensured `format_phone_number` runs `before_validation`.
*   **Controllers:**
    *   `app/controllers/registrations_controller.rb`:
        *   Added `potential_duplicate_found?` private method to check for existing users with the same normalized name and DOB.
        *   Modified the `create` action to call `potential_duplicate_found?` and set `@user.needs_duplicate_review = true` if a match is found.
        *   Permitted `:needs_duplicate_review` in `registration_params` (although it's set directly in the controller action, permitting it ensures consistency if the attribute were ever mass-assigned elsewhere).
*   **Views:**
    *   `app/views/admin/users/index.html.erb`: Updated to visually indicate users flagged with `needs_duplicate_review`.
*   **Tests:**
    *   `test/models/user_test.rb`: Added tests for phone uniqueness validation.
    *   `test/controllers/registrations_controller_test.rb`: Added tests to verify:
        *   Registration fails with a duplicate phone number.
        *   Registration succeeds but sets the `needs_duplicate_review` flag when a Name+DOB match occurs.
        *   Fixed issues related to email template creation in the test setup.

## User Experience

*   **Duplicate Email/Phone:** The user receives a standard validation error ("Email has already been taken", "Phone has already been taken") and cannot complete registration with that specific identifier.
*   **Duplicate Name+DOB:** The user's registration completes successfully. They are logged in and see the welcome message. The account is flagged internally for admin review, but the user experience is uninterrupted.

## Future Considerations

*   Develop an administrative interface or process for reviewing users flagged with `needs_duplicate_review`. This might involve merging accounts, contacting users, or marking the flag as resolved.
*   Consider adding similar soft checks for other potentially identifying information if needed (e.g., address).
