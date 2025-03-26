# Email and Letter Consistency

This document describes the system for ensuring that constituents who prefer physical letters receive all important notifications that would normally be sent via email.

## Background

Some constituents may not have reliable internet access or may prefer physical mail communications. The system now ensures that any email notification sent to a constituent also generates a corresponding printed letter if their communication preference is set to "letter".

## Components

### 1. Print Queue Items

The `PrintQueueItem` model handles all letters that need to be printed and mailed. Each item corresponds to a different type of notification letter:

- `account_created` - When a new account is created
- `income_proof_rejected` - When income proof is rejected
- `residency_proof_rejected` - When residency proof is rejected
- `income_threshold_exceeded` - When income exceeds eligibility threshold
- `application_approved` - When an application is approved
- `registration_confirmation` - When a new user registers
- `other_notification` - For miscellaneous notifications
- `proof_approved` - When a submitted document is approved 
- `max_rejections_reached` - When maximum rejection attempts have been reached
- `proof_submission_error` - When there's an error with a document submission
- `evaluation_submitted` - When an evaluation is submitted

### 2. Letter Templates

Letter templates are stored in `app/views/letters/` with corresponding HTML templates for each letter type. These templates use the same layout (`app/views/layouts/letter.html.erb`) and are rendered to PDF by the `Letters::LetterGeneratorService`.

### 3. Mailer Integration

All mailers have been updated to check the constituent's communication preference before sending an email. If the preference is set to "letter", the mailer will:

1. Send the email as usual
2. Generate a letter using the appropriate template
3. Create a `PrintQueueItem` with the letter attached as a PDF

This ensures that constituents receive notifications in their preferred format.

### 4. Letter Generator Service

The `Letters::LetterGeneratorService` handles:

- Rendering the appropriate letter template
- Generating a PDF of the letter
- Creating and saving a `PrintQueueItem` with the attached PDF

## Maintaining Email-Letter Consistency

To ensure all email notifications have corresponding letter templates:

1. Whenever a new email notification is added, create a matching letter template
2. Update the `PrintQueueItem.letter_type` enum to include the new letter type
3. Add handling for the new letter type in the `Letters::LetterGeneratorService`

### Consistency Check

A Rake task has been added to help identify any inconsistencies between email and letter templates:

```bash
rails letters:check_consistency
```

This task scans all mailer directories for template files and compares them against the available letter templates and `PrintQueueItem.letter_type` values. It reports any email templates that don't have corresponding letter templates.

## Admin Interface

Admins can view and manage print queue items through the Print Queue interface at `/admin/print_queue`. This interface allows them to:

1. View all pending letters
2. Mark letters as printed
3. View letter details and download PDFs

## When Adding New Notification Types

1. Create both email templates (.html.erb and .text.erb) in the appropriate mailer directory
2. Create a letter template in `app/views/letters/`
3. Add the new letter type to the `PrintQueueItem.letter_type` enum
4. Update the `LetterGeneratorService` to handle the new letter type
5. Update the mailer to check for letter preference and generate a letter if needed
6. Run `rails letters:check_consistency` to verify all is working

## Testing

When testing the system, you can check that:

1. Emails are sent regardless of communication preference
2. Letters are generated only for users with letter preference
3. PDFs are properly attached to PrintQueueItems
4. The admin interface correctly displays pending letters
