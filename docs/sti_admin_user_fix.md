# Troubleshooting ActiveRecord::SubclassNotFound for Admin User

**Issue:** `ActiveRecord::SubclassNotFound (Invalid single-table inheritance type: Admin is not a subclass of User)`

**Logged Error Origin:**
- `app/controllers/concerns/authentication.rb:55:in 'Authentication#find_production_session'`
- `app/controllers/concerns/authentication.rb:38:in 'Authentication#current_session'`
- `app/controllers/concerns/authentication.rb:24:in 'Authentication#current_user'`
- `app/controllers/application_controller.rb:26:in 'ApplicationController#check_password_change_required'` or `app/controllers/concerns/authentication.rb:112:in 'Authentication#authenticate_user!'`

**Hypothesis:**
The `users` table likely has a `type` column. When a user record has `type = 'Admin'`, Rails attempts to instantiate an `Admin` class. This error means either:
1. The `Admin` class (`app/models/admin.rb` or `app/models/users/admin.rb`) is missing.
2. The `Admin` class exists but does not inherit from `User`.
3. The `Admin` class is namespaced (e.g., `Users::Admin`) but Rails is looking for `Admin` due to how the `type` column is populated or how STI is configured.

**Troubleshooting Steps:**

1.  **[DONE]** Create `docs/sti_admin_user_fix.md` to track progress.
2.  **[DONE]** Inspect `app/models/user.rb`: Confirmed STI setup. The model uses `Users::Administrator` for admin types (e.g., in `self.system_user`, `admin?` method, and `admins` scope). The error implies a record exists with `type = 'Admin'`.
3.  **[DONE]** Searched for `Admin` and `Administrator` model definitions. Found:
    *   `app/models/admin.rb`
    *   `app/models/administrator.rb`
    *   `app/models/users/admin.rb`
    *   `app/models/users/administrator.rb` (This is the one referenced in `user.rb`)
    The presence of multiple admin-related model files might be causing class loading issues.
4.  **[DONE]** Inspect the content of `app/models/users/administrator.rb`: Defines `module Users; class Administrator < User; end; end`. This is the correct class.
5.  **[DONE]** Inspect the content of `app/models/admin.rb`: This file attempts to alias/bridge `Admin` and `Administrator` to `Users::Administrator`. It references `require_dependency 'users/administrator'` and `Administrator = Users::Administrator unless defined?(Administrator)`. It does *not* define `class Admin < User`. It also mentions an initializer `config/initializers/sti_type_mapping.rb`.
6.  **[DONE]** Inspect the content of `app/models/administrator.rb`: Similar to `app/models/admin.rb`, this file aliases `Administrator` to `Users::Administrator` using `require_dependency 'users/administrator'` and `Administrator = Users::Administrator unless defined?(Administrator)`. It does *not* define `class Administrator < User`. This supports the idea that `Users::Administrator` is the canonical class, and these files are for backward compatibility or aliasing.
7.  **[DONE]** Inspect the content of `app/models/users/admin.rb`: Defines `module Users; class Admin < User; end; end`. This class would be found if `type` in the DB was `'Users::Admin'`. However, the error indicates `type` is `'Admin'`, for which Rails expects a top-level `Admin` class.
8.  **[DONE]** Inspect `config/initializers/sti_type_mapping.rb`:
    *   It includes a `NamespacedStiTypeName` module with a `computed_type` method that strips the `Users::` namespace when writing to the DB (e.g., `Users::Administrator` becomes `Administrator`, `Users::Admin` becomes `Admin`). This means the database *should* contain `Admin` or `Administrator` as type strings, not `Users::Admin` or `Users::Administrator`.
    *   It overrides `ActiveRecord::Base.sti_name_to_class` to look for `Users::#{type_name}` first if `type_name` from DB is un-namespaced (e.g., for `Admin` from DB, it tries `Users::Admin`).
    *   The error `SubclassNotFound` for type `Admin` (from DB) is puzzling because `Users::Admin` exists and inherits from `User`, and this initializer *should* map the DB string `Admin` to the `Users::Admin` class. This suggests a potential load order issue, a conflict, or that the `Users::Admin` class isn't being correctly recognized despite its definition.
    *   **User Feedback:** The immediate issue is `type = 'Admin'` in the database, which needs to be corrected. The long-term standard is `Users::Administrator`.
9.  **[DONE]** Inspect `app/controllers/concerns/authentication.rb`: The error occurs when `Session.includes(:user).find_by(...)` attempts to instantiate a User with `type = 'Admin'`. The authentication code itself is standard; the issue is with STI resolution of the 'Admin' type.
10. **[INVESTIGATING UI ROLE UPDATE BEHAVIOR]**
    *   **Observation:** Production logs show `params[:role]` as "Admin" in `Admin::UsersController#update_role` when the UI select list value is "Users::Administrator". The Stimulus controller (`role_select_controller.js`) appears to send the correct namespaced value.
    *   **Change 1 (Done):** Modified `config/initializers/sti_type_mapping.rb` to comment out the `NamespacedStiTypeName` module and its prepending. This disables the `computed_type` method that demodulized type names before saving to the DB. The goal is for the DB to store full namespaced types (e.g., "Users::Administrator").
    *   **Change 2 (Done):** Added a `Rails.logger.info` statement at the beginning of `Admin::UsersController#update_role` to log the received `params[:role]` value directly. Adjusted success message.
    *   **User Action: Deploy Changes & Test:**
        *   Deploy the modified `sti_type_mapping.rb` and `admin/users_controller.rb`.
        *   In the admin UI, change a user's role.
        *   Check Heroku logs for the new logger output from `Admin::UsersController` to see the actual `params[:role]` value received.
        *   Check the database to see what `type` string was stored for the updated user. It should now be the full namespaced string (e.g., "Users::Administrator").
11. **[DATA CORRECTION - MANUAL via Heroku Console]**
    *   **User Action (After UI behavior is confirmed/fixed):** Manually update existing incorrect user records in the Heroku console to ensure all `type` attributes use the full namespaced class name (e.g., "Users::Administrator", "Users::Constituent").
    *   **Specific Updates Needed (Target: Full Namespaced Types):**
        *   `Admin` -> `Users::Administrator`
        *   `Administrator` -> `Users::Administrator`
        *   `Users::Admin` -> `Users::Administrator`
        *   `Constituent` -> `Users::Constituent`
        *   `Vendor` -> `Users::Vendor` (if applicable)
        *   `Trainer` -> `Users::Trainer` (if applicable)
        *   `Evaluator` -> `Users::Evaluator` (if applicable)
    *   Console commands using `User.where(type: 'OldType').update_all(type: 'New::Namespaced::Type')` have been provided.
    *   **User Action:** Delete the generated (but unused) migration file: `rm db/migrate/20250507150650_correct_user_types_for_admin_roles.rb`.
12. **[DONE]** Controller Enhancement - Update `Admin::UsersController#update_role`:
    *   **Issue**: After disabling `computed_type`, the controller was receiving both namespaced and demodulized role params. Additionally, when changing from a type with specific validations (like `Users::Vendor`) to another type, those validations could still interfere.
    *   **Change 1**: Added a `VALID_USER_TYPES` mapping to handle both namespaced and demodulized role strings, ensuring consistent namespaced types are saved.
    *   **Change 2**: Implemented more robust type conversion using `user.becomes(new_klass)` which creates a new instance of the target type.
    *   **Change 3**: Added explicit nullification of type-specific fields when changing from `Users::Vendor` to prevent validation crossover:
      ```ruby
      if user.type_was == 'Users::Vendor' && !converted_user.is_a?(Users::Vendor)
        Rails.logger.info "Admin::UsersController#update_role - Nullifying vendor-specific fields..."
        converted_user.business_name = nil
        converted_user.business_tax_id = nil
        converted_user.terms_accepted_at = nil
        converted_user.w9_status = nil
      end
      ```
    *   **Result**: Type changes now work correctly even when vendor-specific fields would otherwise cause validation errors.

13. **[DONE]** Test Coverage - Create and update tests for STI:
    *   Created focused STI tests in `test/sti_user_test.rb` to verify:
      1. Namespaced type storage and retrieval (`test_namespaced_sti_type_storage_and_retrieval`)
      2. Clean type transitions without validation crossover (`test_vendor_to_evaluator_transition_without_validation_crossover`)
    *   Updated `test/factories/users.rb`:
      1. Fixed `:admin` factory to use `type { 'Users::Administrator' }` instead of `'Administrator'`
      2. Enhanced `:vendor_user` factory with all required fields to create valid vendors
    *   All tests are now passing, confirming our STI implementation is working correctly.

14. **[IN PROGRESS]** Code cleanup after UI fix, data correction, and verification:
    *   **[DONE] Code Cleanup - Step 1: Removed `app/models/users/admin.rb`**
        * Successfully removed the redundant `Users::Admin` class after verifying it wasn't directly used in the codebase.
        * All STI-specific tests pass after removal.
    *   **[PENDING] Code Cleanup - Step 2: Review aliasing files** (`app/models/admin.rb`, `app/models/administrator.rb`).
    *   **[PENDING] Code Cleanup - Step 3: Further Review `config/initializers/sti_type_mapping.rb`**.
        *   With `computed_type` logic removed/disabled, and if `params[:role]` is confirmed to arrive namespaced, the `sti_name_to_class` override might also be simplified or removed if the DB consistently stores full namespaced types.
    *   **Overall Goal for Cleanup:** Standardize on full namespaced types in DB and code, simplifying STI handling.

## Summary of Changes

1. **Disabled type demodulization**: Commented out the `computed_type` method in `sti_type_mapping.rb` to ensure full namespaced types are stored in the database.

2. **Enhanced controller logic**: 
   - Added mapping for both namespaced and demodulized role params
   - Used `becomes` method for proper type conversion
   - Explicitly nullified type-specific fields when changing types to prevent validation crossover

3. **Improved test coverage**:
   - Added focused STI tests in `test/sti_user_test.rb`
   - Fixed and enhanced user factories

4. **Next steps**:
   - Data correction via console (see section 11)
   - Code cleanup (section 14)

## Key Technical Insights

1. **STI Type Storage**: Rails expects the value in the `type` column to correspond to the actual class name. For namespaced classes, this means storing the full namespace (e.g., "Users::Administrator").

2. **Validation Context During Type Changes**: When changing a record's STI type with `update(type: new_type)`, validations from the original type can still fire. The `becomes` method helps by returning a new instance of the target class, but explicit field nullification may still be needed for fields with validations.

3. **Class Loading and Resolution**: Rails' STI resolution depends on proper class loading order and constant definition. The `sti_name_to_class` override helps map demodulized type strings from DB to their namespaced classes.
