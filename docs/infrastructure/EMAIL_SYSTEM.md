# Email System Guide

MAT Vulcan delivers, receives, and even prints email content through one unified pipeline. This doc explains **where templates live, how inbound mail is routed, how letters are generated, and how Postmark is wired up**.

---

## 1 · Template Management

| Aspect | Details |
|--------|---------|
| Storage | `email_templates` DB table |
| Lookup constant | `EmailTemplate::AVAILABLE_TEMPLATES` |
| Format | Records with `name`, `format` (`:html` / `:text`), `subject`, `body` |
| Placeholders | `%{first_name}` or `%<amount>.2f` |

Seed/update:

```bash
rails db:seed:email_templates   # or rake db:seed_manual_email_templates
```

**Mailer pattern**

```ruby
tpl = EmailTemplate.find_by!(name: 'user_mailer_password_reset', format: :html)
subj, html = tpl.render(user_first_name: @user.first_name, reset_url: ...)
mail(to: @user.email, subject: subj) { format.html { render html: html.html_safe } }
```

Admin UI lets staff **edit, preview, and send test mails** — no code deploys for copy changes.

---

## 2 · Inbound Email

*Rails Action Mailbox + Postmark* handles attachments for proofs & medical certs.

| ENV | Example |
|-----|---------|
| `INBOUND_EMAIL_PROVIDER` | `postmark` |
| `INBOUND_EMAIL_ADDRESS` | `af7e…@inbound.postmarkapp.com` |
| `RAILS_INBOUND_EMAIL_PASSWORD` | webhook token |

Routing (`ApplicationMailbox`):

```text
inbound address → ProofSubmissionMailbox
subject ~ /medical certification/i → MedicalCertificationMailbox
else → default mailbox
```

Local test:

```bash
bin/test-inbound-emails
ultrahook postmark 3000   # forwards webhooks in dev
```

What users do:

* **Constituent proofs** – email docs to inbound address.  
* **Providers** – email signed certification + app ID in subject.

---

## 3 · Letter Generation

Some users choose *physical mail*. The same template renders to PDF.

```ruby
Letters::TextTemplateToPdfService
  .new(template_name: 'application_notifications_account_created',
       recipient: user,
       variables: { first_name: user.first_name })
  .queue_for_printing
```

* Creates `PrintQueueItem` → admin prints from `/admin/print_queue`.

---

## 4 · Postmark Setup

### 4.1 Message Streams

| Stream | Purpose |
|--------|---------|
| `outbound` | Auth & transactional (password reset) |
| `notifications` | Status updates, voucher assigned |

Use in mailer:

```ruby
mail(to: user.email, subject: 'Hi', message_stream: 'notifications')
```

### 4.2 Tracking & Webhooks

* `track_opens: true` on selected mail.  
* `UpdateEmailStatusJob` polls or webhooks update delivery state.  
* Bounce → flag `user.email_bounced`.

### 4.3 Debug Logs

```
POSTMARK PAYLOAD (ORIGINAL)
POSTMARK PAYLOAD (MODIFIED)
POSTMARK SUCCESS / POSTMARK ERROR
```

Enable in `config/initializers/postmark_debugger.rb`.

---

## 5 · Testing

| Topic | How |
|-------|-----|
| Template render | Mock template → `template.render(**vars)` |
| Inbound flow | `bin/test-inbound-emails`, Action Mailbox dashboard |
| Letter PDF | Specs for `TextTemplateToPdfService` + `PrintQueueItem` |
| Smoke send | Admin UI “Send test email” |

Example mock:

```ruby
tpl = mock_template('%{first}', 'Hello %{first}')
subj, body = tpl.render(first: 'Ada')
```

---

## 6 · Troubleshooting Cheatsheet

| Symptom | Check |
|---------|-------|
| **“Template not found”** | Name/format mismatch in DB |
| **Inbound mail ignored** | Webhook password & routing rules |
| **Letter generation fails** | Text template exists? all variables supplied? |
| **Wrong stream** | `message_stream` param in mailer |

Tools: Postmark dashboard (delivery & webhooks) · `/rails/conductor/action_mailbox/inbound_emails` · `/admin/print_queue`.