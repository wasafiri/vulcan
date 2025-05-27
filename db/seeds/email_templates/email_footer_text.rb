# Seed File for "email_footer_text"
EmailTemplate.create_or_find_by!(name: 'email_footer_text', format: :text) do |template|
  template.subject = 'Email Footer Text'
  template.description = 'Standard text footer used in all email templates'
  template.body = <<~TEXT
    --
    <%= organization_name %>
    Email: <%= contact_email %>
    Website: <%= website_url %>

    <% if defined?(show_automated_message) && show_automated_message %>
    This is an automated message. Please do not reply directly to this email.
    <% end %>
  TEXT
  template.version = 1
end
puts 'Seeded email_footer_text (text)' if ENV['VERBOSE_TESTS'] || Rails.env.development?
