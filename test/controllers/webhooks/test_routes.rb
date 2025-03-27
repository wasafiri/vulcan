# frozen_string_literal: true

# Test-specific routes for webhook controllers
# Only load these routes in the test environment
Rails.application.routes.draw do
  # Use our test controllers for webhook routes in tests
  namespace :webhooks do
    # Override the email_events route to use our test controller
    post 'email_events', to: 'test_email_events#create'
  end
end
