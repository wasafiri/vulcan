# Honeybadger is Not Currently Installed
# Honeybadger Error Tracking

This document explains the Honeybadger error tracking setup in this application and provides guidance on how to use it effectively.

## Configuration

Honeybadger is configured using a combined approach:

1. **YAML Configuration** (`config/honeybadger.yml`): Contains static configuration settings, environment-specific settings, and parameter filtering.
2. **Ruby Initializer** (`config/initializers/honeybadger.rb`): Contains dynamic configuration like notification filters, event tracking, and custom error grouping.

## Setup Requirements

To use Honeybadger, you need to:

1. Set the `HONEYBADGER_API_KEY` environment variable with your project's API key from the Honeybadger dashboard.
2. Deploy your application - error tracking will automatically be enabled.

## Key Features Enabled

### Error Tracking and Filtering

- Automatic capture of uncaught exceptions
- Custom fingerprinting of `ActiveRecord::RecordNotFound` errors by model
- Rate limiting of database connection errors
- Filtering of sensitive data in error messages
- Ignored errors for common non-critical cases

### Context and User Information

- User context added to errors when available (using the `Current.user` pattern)
- Controller and action names included with error reports
- Request parameters attached to error reports (with sensitive data filtered)

### Performance Monitoring

- SolidQueue metrics (if using SolidQueue)
- Rails instrumentation for performance insights
- Custom event tracking

## Manual Error Reporting

You can manually report errors or custom events:

```ruby
# Report an exception with context
begin
  # code that might raise an exception
rescue => e
  Honeybadger.notify(e, context: {
    user_id: current_user.id,
    custom_data: "Additional information"
  })
end

# Report a custom error message
Honeybadger.notify("Something went wrong", context: {
  severity: "warning",
  source: "background_job"
})
```

## User Feedback Features

Honeybadger offers two features to enhance user experience during errors:

1. **User Informer**: Displays the error ID in HTML comments when users encounter errors.
2. **Feedback Form**: Allows users to submit feedback when they encounter errors.

Both of these features are enabled by default.

## Performance Considerations

- Error notifications are queued and sent asynchronously
- Rate limiting is applied to prevent flooding from repetitive errors
- In development and test environments, notifications are disabled by default

## Extending the Configuration

To extend the Honeybadger configuration:

1. For static configuration, modify `config/honeybadger.yml`
2. For dynamic configuration, add code to `config/initializers/honeybadger.rb`

## Additional Resources

- [Honeybadger Documentation](https://docs.honeybadger.io/ruby/index.html)
- [Ruby API Reference](https://docs.honeybadger.io/ruby/reference.html)
- [Honeybadger Dashboard](https://app.honeybadger.io/)
