# Adding Alternate Contact to Applications

This guide covers the minimal steps needed to add an optional alternate contact (name + phone or email) to both web and admin paper-application workflows.

## 1. Generate & run the migration

```bash
bin/rails generate migration AddAlternateContactFieldsToApplications \
  alternate_contact_name:string \
  alternate_contact_phone:string \
  alternate_contact_email:string

bin/rails db:migrate
```

## 2. Model: permit & validate

In **app/models/application.rb**:

```ruby
# Optional formats
validates :alternate_contact_phone,
  format: { with: /\A\+?[\d\-\(\)\s]+\z/, allow_blank: true }
validates :alternate_contact_email,
  format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
```

## 3. Controllers: strong params

Add the three fields to each `application_params` method:

```ruby
# e.g. in Admin::ApplicationsController and PaperApplicationsController
params.require(:application).permit(
  …,
  :alternate_contact_name,
  :alternate_contact_phone,
  :alternate_contact_email
)
```

Also in **ConstituentPortal::ApplicationsController**, under `permit`.

## 4. Views: optional fields

### Admin paper-app (`app/views/admin/paper_applications/new.html.erb`)

Add inside the `<fieldset>` for medical provider or at the end:

```erb
<fieldset class="mb-6">
  <legend class="text-lg">Alternate Contact (optional)</legend>
  <%= fields_for :application do |a| %>
    <div>
      <%= a.label :alternate_contact_name, "Name" %>
      <%= a.text_field :alternate_contact_name, class: "w-full" %>
    </div>
    <div class="grid grid-cols-2 gap-4 mt-2">
      <div>
        <%= a.label :alternate_contact_phone, "Phone" %>
        <%= a.telephone_field :alternate_contact_phone, class: "w-full" %>
      </div>
      <div>
        <%= a.label :alternate_contact_email, "Email" %>
        <%= a.email_field :alternate_contact_email, class: "w-full" %>
      </div>
    </div>
  <% end %>
</fieldset>
```

### Public portal (`app/views/constituent_portal/applications/new.html.erb`)

Added right before the Document Upload Section:

```erb
<!-- Alternate Contact Section (optional) -->
<section aria-labelledby="alternate-contact-section-title" class="space-y-4 p-4 bg-gray-50 rounded">
  <h2 id="alternate-contact-section-title" class="text-lg font-medium text-gray-900">Alternate Contact (Optional)</h2>
  <p class="text-sm text-gray-700">You may provide an alternate contact person who can be contacted regarding your application.</p>
  
  <div class="space-y-4">
    <div>
      <%= form.label :alternate_contact_name, "Name", class: "block text-sm font-medium text-gray-700" %>
      <%= form.text_field :alternate_contact_name, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" %>
    </div>
    
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div>
        <%= form.label :alternate_contact_phone, "Phone", class: "block text-sm font-medium text-gray-700" %>
        <%= form.telephone_field :alternate_contact_phone, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" %>
      </div>
      <div>
        <%= form.label :alternate_contact_email, "Email", class: "block text-sm font-medium text-gray-700" %>
        <%= form.email_field :alternate_contact_email, class: "mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" %>
      </div>
    </div>
  </div>
</section>
```

## 5. Mailer: CC if provided

In **app/mailers/application_notifications_mailer.rb**:

```ruby
def application_submitted(application)
  @application = application
  @user = application.user

  # Set up mail options with CC for alternate contact if provided
  mail_options = {
    to: @user.email,
    subject: 'Your Application Has Been Submitted',
    message_stream: 'notifications'
  }

  # Add CC for alternate contact if email is provided
  mail_options[:cc] = @application.alternate_contact_email if @application.alternate_contact_email.present?

  mail(mail_options)
end
```

## 6. Final steps

- Restart your server.
- Run tests: `bin/rails test`.
- Verify forms show the fields, and that values persist.

---

After following these steps, alternate contacts can be recorded and optionally CC’d on submission emails.
