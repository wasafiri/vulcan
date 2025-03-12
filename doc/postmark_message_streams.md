# Postmark Message Streams Implementation

This document explains how message streams are implemented in our application.

## Overview

Postmark allows categorizing emails into different "streams" which can have different sending rules, tracking settings, and delivery configurations. In our application, we use two primary streams:

1. `outbound` - For transactional emails (e.g., password resets, system notifications)
2. `notifications` - For customer-facing notifications (e.g., voucher assignments, status updates)

## Implementation

### Setting Message Streams

We set the message stream directly in each mailer method:

```ruby
mail(
  to: recipient.email,
  subject: "Subject line",
  message_stream: "outbound"  # or "notifications"
)
```

### Configuration Files

We use two initializers to ensure proper handling of message streams:

1. `config/initializers/postmark_format.rb` - Sets basic Postmark configuration to prevent unnecessary headers
2. `config/initializers/postmark_debugger.rb` - Ensures that message streams are correctly formatted in the Postmark API payload

### Payload Transformation

When an email is about to be sent to Postmark, we:

1. Log the original payload for debugging
2. Convert any `X-PM-Message-Stream` headers to a top-level `MessageStream` parameter
3. Remove the `ReplyTo` field if it's redundant with the `From` field
4. Simplify headers to match our known working format
5. Log the modified payload before sending

## Testing

A test suite in `test/mailers/message_stream_test.rb` verifies that each mailer correctly sets its message stream.

## Debugging

If you encounter issues with message streams, check the logs for:
- `POSTMARK PAYLOAD (ORIGINAL)` - The original payload before transformation
- `POSTMARK PAYLOAD (MODIFIED)` - The modified payload after our transformations
- `POSTMARK SUCCESS` - Indicates successful delivery
- `POSTMARK ERROR` - Contains error details if delivery failed

## Tips for Adding New Mailers

When adding a new mailer:

1. Determine the appropriate message stream based on the email's purpose
2. Add the `message_stream` parameter to the `mail()` method
3. Add tests to verify the correct message stream is used
