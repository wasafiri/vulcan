# Mailer Template Management – Text Templates and Letter Generation

This document outlines our approach for managing email templates in our application, including how these templates are now also used for letter generation. This document describes the improvements made, details on template structure, seeding process, changes to mailer code, letter generation, and test considerations.

---

## 1. Overview

We have successfully migrated our email templates from filesystem-based `.text.erb` files to database records stored in the `email_templates` table. This migration enables management of templates via the admin interface (`admin/email_templates#index` and `#show`) and provides a single source of truth for both email and letter generation.

---

## 2. Improvements Made

- **Single Source of Truth:** We now use the same database-stored templates for both emails and printed letters, eliminating duplication and ensuring consistency between digital and physical communications.
- **Admin Management:** Templates can be edited via the admin interface, with changes tracked through versioning.
- **Simplified Letter Generation:** We've replaced the complex `LetterGeneratorService` with a new `TextTemplateToPdfService` that directly uses the database templates.
- **Simplified Variable Substitution:** All templates now use a consistent string interpolation format for variable substitution (`%{placeholder}` or `%<placeholder>s`), making templates easier to maintain and understand.
- **Improved Template Preview:** The "Send Test Email" page now displays a full preview of the rendered template with all variables properly substituted, allowing administrators to see exactly how the email will appear before sending it.
- **Robust Variable Handling:** The template rendering system now properly handles both traditional `%{var}` style and printf-style `%<var>s` format variables, ensuring consistent variable replacement regardless of format style.
- **Controller-Based Preview Rendering:** Templates are now pre-rendered in the controller with sample data for previews, improving the user experience and making it easier to identify formatting issues.

---

## 3. Template Structure

- **Configuration:**  
  The configuration for each email template is defined in the `EmailTemplate::AVAILABLE_TEMPLATES` constant in `app/models/email_template.rb`. This configuration specifies the required and optional variables for each template.

- **Storage Format:**  
  Templates are stored in the database with:
  - `name`: The template identifier (e.g., `application_notifications_account_created`)
  - `format`: Either `:html` or `:text` (we maintain both formats for emails)
  - `subject`: The email subject line
  - `body`: The content with `%{placeholder}` or `%<placeholder>s` variables

- **Variable Placeholders:**  
  All variables are defined using standard Ruby string interpolation formats:
  - `%{variable_name}` - Simple format
  - `%<variable_name>s` - Printf-style format (useful for applying formatting to the variable)
  
  Both formats are fully supported in text and HTML versions of templates.

---

## 4. Seeding Database Templates

Templates are seeded using files in `db/seeds/email_templates/`, with each template having its own file:

- `db/seeds/email_templates/application_notifications_account_created.rb`
- `db/seeds/email_templates/user_mailer_password_reset.rb`
- etc.

These seed files create `EmailTemplate` records with appropriate name, format, subject, and body values. The main seeding script is `db/seeds/email_templates.rb`, which loads all individual template seed files.

To seed the database, run:
```
rails db:seed:email_templates
```

Or use the dedicated rake task:
```
rake db:seed_manual_email_templates
```

---

## 5. Mailer Implementation

Mailers retrieve templates from the database:

```ruby
def password_reset
  @user = params[:user]
  template_name = 'user_mailer_password_reset'
  html_template = EmailTemplate.find_by!(name: template_name, format: :html)
  text_template = EmailTemplate.find_by!(name: template_name, format: :text)
  
  variables = {
    user_first_name: @user.first_name,
    reset_url: edit_password_url(token: @user.generate_token_for(:password_reset))
    # Add other variables needed by the template
  }
  
  # Render subject and bodies
  rendered_subject, rendered_html_body = html_template.render(**variables)
  _, rendered_text_body = text_template.render(**variables)
  
  # Create mail object with rendered content
  message = mail(
    to: @user.email,
    subject: rendered_subject
  ) do |format|
    format.html { render html: rendered_html_body.html_safe }
    format.text { render plain: rendered_text_body }
  end
  
  message
end
```

---

## 6. Variable Population in Mailer Methods

When a mailer method runs, it must populate all required variables for the template. Let's examine how this works using the `account_created` method in `ApplicationNotificationsMailer` as an example:

```ruby
# In ApplicationNotificationsMailer
def account_created(constituent, temp_password)
  template_name = 'application_notifications_account_created'
  
  # Fetch templates from database
  html_template = EmailTemplate.find_by!(name: template_name, format: :html)
  text_template = EmailTemplate.find_by!(name: template_name, format: :text)
  
  # Prepare all required and optional variables
  variables = {
    constituent_first_name: constituent.first_name,
    constituent_email: constituent.email,
    temp_password: temp_password,
    sign_in_url: new_user_session_url(host: default_url_options[:host]),
    header_html: header_html(title: header_title, logo_url: header_logo_url),
    header_text: header_text(title: header_title, logo_url: header_logo_url),
    footer_html: footer_html(contact_email: footer_contact_email, website_url: footer_website_url,
                           show_automated_message: footer_show_automated_message),
    footer_text: footer_text(contact_email: footer_contact_email, website_url: footer_website_url,
                           show_automated_message: footer_show_automated_message)
  }.compact
  
  # Render subject and bodies using the templates
  rendered_subject, rendered_html_body = html_template.render(**variables)
  _, rendered_text_body = text_template.render(**variables)
  
  # Create and return the mail object
  message = mail(to: constituent.email, subject: rendered_subject) do |format|
    format.html { render html: rendered_html_body.html_safe }
    format.text { render plain: rendered_text_body }
  end
  
  message
end
```

### How Template Variables Are Populated

For each template, the variables come from several sources:

1. **Direct Method Parameters**: Values passed directly to the mailer method (e.g., `constituent`, `temp_password`)
2. **Model Attributes**: Data extracted from models (e.g., `constituent.first_name`, `constituent.email`)
3. **Generated URLs**: Using Rails URL helpers (e.g., `new_user_session_url`)
4. **Header and Footer Helpers**: Using the `Mailers::SharedPartialHelpers` module

### Shared Partial Helpers

The `header_text`, `footer_text`, and other similar helper methods come from the `Mailers::SharedPartialHelpers` module, which:

1. Renders standardized headers and footers for emails
2. Manages common elements like titles, logos, and contact information
3. Supports both HTML and text formats
4. Handles optional parameters gracefully

These helpers ensure that all emails have a consistent look and feel while still allowing customization through parameters.

### Email Template Definition and Required Variables

The required variables for each template are defined in the `AVAILABLE_TEMPLATES` constant in the `EmailTemplate` model. For example:

```ruby
'application_notifications_account_created' => {
  description: 'Sent when a new user account is created.',
  required_vars: %w[constituent_first_name constituent_email temp_password sign_in_url header_text footer_text],
  optional_vars: %w[title show_automated_message logo subtitle]
}
```

The mailer method must provide values for all required variables, while optional variables can be omitted.

---

## 7. Letter Generation

The new `TextTemplateToPdfService` generates PDF letters from the text version of email templates:

```ruby
# Using the service in mailers
if user.communication_preference == 'letter'
  Letters::TextTemplateToPdfService.new(
    template_name: 'application_notifications_account_created',
    recipient: user,
    variables: {
      email: user.email,
      temp_password: temp_password,
      first_name: user.first_name,
      last_name: user.last_name
    }
  ).queue_for_printing
end
```

### Key Features of TextTemplateToPdfService:

1. **Reuses Email Templates:** Uses the text-format email templates from the database
2. **Variable Substitution:** Replaces `%{placeholder}` and `%<placeholder>s` variables with actual values
3. **Consistent Formatting:** Applies consistent PDF styling and layout
4. **Print Queue Integration:** Automatically creates `PrintQueueItem` records for printing

---

## 8. Admin Interface

The admin interface at `/admin/email_templates` allows viewing and editing templates:

- **Index View:** Lists all email templates with name, format, and management actions
- **Show View:** Displays detailed information about a template, including its variables
- **Edit View:** Allows editing the template's subject and body
- **Test Email View:** Provides a preview of how the template will appear with variables substituted, along with a form to send a test email to any address

### Test Email Preview

The "Send Test Email" feature provides administrators with:

1. **WYSIWYG Preview:** See exactly how the email will appear with all variables properly rendered
2. **Subject Preview:** View the rendered email subject line with all variables substituted
3. **Body Preview:** Preview the complete body content, including all replaced variables
4. **Format-Specific Display:** HTML emails are shown with proper formatting, while text emails preserve whitespace
5. **Test Sending:** The ability to send a test email to any email address for final verification

This preview functionality makes it much easier to ensure templates are correctly formatted and all variables are properly defined before sending emails to constituents.

---

## 9. Testing Considerations

Our tests have been adapted to work with the new database template approach:

### Mailer Tests

Mailer tests have been updated to:
- Properly mock `EmailTemplate.find_by!` calls for both HTML and text formats.
- Assert against both the HTML and text parts of the generated emails.
- Include checks for letter generation via `TextTemplateToPdfService` where the corresponding mailer method calls this service (e.g., using `Letters::TextTemplateToPdfService.any_instance.expects(:queue_for_printing).once` when the recipient's `communication_preference` is 'letter').

### Test Helpers

Most mailer tests use mock templates to avoid database dependencies:

```ruby
# Helper to create mock templates that performs interpolation
def mock_template(subject_format, body_format)
  template = mock('email_template')
  template.stubs(:render).with(any_parameters).returns do |**vars|
    rendered_subject = subject_format % vars
    rendered_body = body_format % vars
    [rendered_subject, rendered_body]
  end
  template
end

# Stubbing template lookup
EmailTemplate.stubs(:find_by!).with(name: 'template_name', format: :html).returns(@mock_html)
EmailTemplate.stubs(:find_by!).with(name: 'template_name', format: :text).returns(@mock_text)
```

### System Tests for Email Templates

System tests have been added to verify:
1. Proper rendering of email templates in the admin interface
2. Variable substitution in the preview functionality
3. The "Send Test Email" workflow
4. Template editing and versioning

These tests ensure that administrators can reliably manage templates through the web interface.

### Letter Generation Tests

The `TextTemplateToPdfService` has dedicated tests in `test/services/letters/text_template_to_pdf_service_test.rb` that verify:

1. PDF generation from database templates
2. Variable substitution in templates
3. Correct handling of missing templates
4. Print queue item creation

### Integration Testing

If you need to test the entire email-to-letter workflow, ensure you:

1. Set up the necessary database templates
2. Create a constituent with `communication_preference == 'letter'`
3. Trigger the mailer action
4. Verify a `PrintQueueItem` was created with the correct template name

---

## 10. Next Steps

1. **Complete Missing Mailer Tests:** Add tests for any mailer methods that don't yet have test coverage.

2. **Review and Update Mailer Code:** Some mailer methods might still reference or expect filesystem-based templates. Review these methods and update them to use the database templates.

3. **Consider HTML Template Management:** While our letter generation only uses text templates, our email system still maintains HTML templates. Consider strategies for managing and updating HTML templates, especially for complex emails.

4. **Improve Admin Template Editor:** Add features to the admin editor like template variable validation, syntax highlighting, and better version comparison.

5. **Optimize Template Loading:** Implement caching for templates to reduce database queries when sending multiple emails.

6. **Documentation and Training:** Ensure all developers understand the new template system and how to use it effectively.

---

## 11. Conclusion

Our email and letter template system uses a single source of truth in the database, making it easier to manage, update, and maintain consistent communications across both digital and physical channels. The admin interface enables non-technical staff to make template changes, preview how emails will appear to recipients, and send test emails for verification. The enhanced variable substitution system ensures reliable template rendering regardless of the variable format used, resulting in a more robust and user-friendly template management experience.

*End of Document*
