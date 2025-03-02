# Handling Orphaned Applications

This document describes the issue of orphaned applications in the MAT Vulcan system and provides solutions for fixing and preventing this issue.

## The Issue

An "orphaned application" is an `Application` record in the database that has a `nil` value for its `user_id` or references a user that no longer exists. This can happen if:

1. A user is deleted without properly handling their associated applications
2. An application is created without a valid user association
3. Database inconsistencies occur due to failed transactions or other issues

When orphaned applications exist, they can cause errors in the admin dashboard, such as:

```
ActionView::Template::Error (undefined method 'full_name' for nil)
```

## Immediate Fix

We've implemented a defensive coding approach in the application views to handle nil users gracefully:

```ruby
# In app/views/admin/applications/_applications_table.html.erb
<%= application.user&.full_name || "Unknown User" %>
<%= application.user&.phone || "No phone" %>
<%= application.user&.email || "No email" %>
```

The `&.` safe navigation operator prevents errors by returning nil instead of raising an exception when `application.user` is nil.

## Data Integrity Fix

We've created a migration to add a foreign key constraint that will prevent this issue in the future:

```ruby
# In db/migrate/YYYYMMDDHHMMSS_add_foreign_key_constraint_to_applications.rb
add_foreign_key :applications, :users, on_delete: :restrict
```

This constraint will:
- Prevent applications from being created without a valid user
- Prevent users from being deleted if they have associated applications

## Rake Tasks for Identifying and Fixing Orphaned Applications

Before running the migration, you should identify and fix any existing orphaned applications. We've created Rake tasks to help with this:

### Finding Orphaned Applications

```bash
bin/rails data_integrity:find_orphaned_applications
```

This will list all orphaned applications in the system.

### Fixing Orphaned Applications

You have two options for fixing orphaned applications:

1. **Delete them** (if they're not needed):

```bash
bin/rails data_integrity:fix_orphaned_applications[delete]
```

2. **Assign them to a default user**:

```bash
bin/rails data_integrity:fix_orphaned_applications[assign,admin@example.com]
```

Replace `admin@example.com` with the email of an existing user who should own these applications.

## Recommended Workflow

1. Run `bin/rails data_integrity:find_orphaned_applications` to identify orphaned applications
2. Decide whether to delete them or assign them to a default user
3. Run the appropriate fix task
4. Run the migration to add the foreign key constraint: `bin/rails db:migrate`

## Preventing Future Issues

To prevent this issue from occurring in the future:

1. Always use the foreign key constraint (added by the migration)
2. When deleting users, ensure their applications are properly handled (transferred or deleted)
3. Use transactions when creating or updating related records
4. Add validation in the Application model to ensure user_id is present and valid

## Monitoring

Periodically run the `data_integrity:find_orphaned_applications` task to check for any new orphaned applications. If any are found, investigate how they were created to prevent similar issues in the future.
