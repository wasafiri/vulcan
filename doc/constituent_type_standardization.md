# Constituent Type Standardization

## Problem Overview

The application was experiencing issues with proof attachments not being correctly associated with users due to inconsistent user type values.

The root cause was that the codebase had two different formats for the User.type field for constituents:
- `Users::Constituent` (namespace + class name)
- `Constituent` (simple class name)

This inconsistency was causing problems with Rails' Single Table Inheritance (STI) role checking methods.

## The Fix

Instead of a database migration, we've made the following code changes to standardize constituent handling:

1. Updated `ConstituentPortal::ApplicationsController#update_user_attributes` to always ensure type is "Constituent" for the constituent? method to work properly with Rails STI conventions.

2. Modified `Applications::PaperApplicationService` to explicitly set type to "Constituent" when creating new users.

3. Updated `Admin::PaperApplicationsController#new` to initialize new constituent forms with the correct type value.

4. Updated fixtures and factories to use "Constituent" (without namespace) consistently.

## Technical Details

The `User#constituent?` method performs role checking based on the `type` field in the database. This method works by checking if the type equals the singular form of the method name's prefix. For a check like `user.constituent?`, Rails looks for `type == "Constituent"`.

When we were storing `Users::Constituent` in the database, this role check was failing, even though the object was a constituent. This is standard Rails STI behavior.

## Implementation Notes

- We've opted to fix the issue at the code level rather than through a database migration.
- This change ensures consistent user type values in all new data.
- Tests have been updated to use the standardized type values.

## Update (March 17, 2025)

We found there was still an issue with paper application submissions where the class types were mismatched. The problem was that while we were setting `type = "Constituent"` in the database column, we were still instantiating the objects as `Users::Constituent` rather than `Constituent`.

The fixes implemented:

1. Changed `PaperApplicationService` to instantiate the `Constituent` class directly:
   ```ruby
   # Old
   @constituent = Users::Constituent.new(attrs).tap do |c|
     # ...
     c.type = "Constituent" # Setting the type isn't enough
   end
   
   # New
   @constituent = Constituent.new(attrs).tap do |c|
     # ... 
     # No need to set type as it will automatically be "Constituent"
   end
   ```

2. Updated the controller's `new` action to initialize with the correct class:
   ```ruby
   # Old
   @paper_application = {
     application: Application.new,
     constituent: Users::Constituent.new.tap { |c| c.type = "Constituent" }
   }
   
   # New
   @paper_application = {
     application: Application.new,
     constituent: Constituent.new
   }
   ```

3. Made sure the error case also uses the correct class:
   ```ruby
   # Old
   @paper_application = {
     application: service.application || Application.new,
     constituent: service.constituent || Users::Constituent.new
   }
   
   # New
   @paper_application = {
     application: service.application || Application.new,
     constituent: service.constituent || Constituent.new
   }
   ```

This ensures that the Ruby object's class matches what Rails expects for STI, not just the database column value.

## Future Considerations

When developing new features:
- Always use `Constituent` (without namespace) for the type field
- For class references, continue using the fully qualified `Users::Constituent` when needed
