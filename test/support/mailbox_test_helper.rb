# frozen_string_literal: true

# Helper module for testing ActionMailbox functionality
#
# This module provides utility methods and setup for mailbox tests:
# - Configures ActionMailbox and ActionMailer for testing
# - Sets up test passwords for Postmark ingress
# - Provides helper methods for creating test emails and attachments
#
# Usage:
# Add `include MailboxTestHelper` in your test class to use these helpers
#
# Key dependencies:
# - ActionMailbox - Rails framework for processing inbound emails
# - Mail - Ruby gem for creating and parsing emails
# - Base64 - Used for encoding/decoding email attachments
#
# Related files:
# - app/mailboxes/* - Contains all mailboxes that process inbound email
# - config/initializers/01_inbound_email_config.rb - Configuration for inbound email
# - config/initializers/02_action_mailbox.rb - ActionMailbox configuration

module MailboxTestHelper
  extend ActiveSupport::Concern

  # Automatically include this module in ActionMailbox::TestCase
  included do
    setup do
      # Ensure delivery method is set for the test
      ActionMailer::Base.delivery_method = :test
      ActionMailer::Base.perform_deliveries = true
      ActionMailer::Base.deliveries.clear

      # Configure ActionMailbox for testing
      Rails.application.config.action_mailbox.ingress = :test

      # Set the ingress password for Postmark tests if needed
      if Rails.application.config.action_mailbox.respond_to?(:ingress_password)
        @original_ingress_password = Rails.application.config.action_mailbox.ingress_password
        Rails.application.config.action_mailbox.ingress_password = 'test_password'
      end

      # Set up attachment mocks if available
      setup_attachment_mocks_for_audit_logs if respond_to?(:setup_attachment_mocks_for_audit_logs)
    end

    teardown do
      # Restore original ingress password if it was changed
      if Rails.application.config.action_mailbox.respond_to?(:ingress_password) && @original_ingress_password
        Rails.application.config.action_mailbox.ingress_password = @original_ingress_password
      end
    end
  end

  # NOTE: This helper should be manually included in each test file that needs it
  # by adding "include MailboxTestHelper" within the test class definition

  # Helper methods for testing mailboxes

  # Creates an email attachment with the given filename and content
  def create_email_attachment(filename, content = 'Sample content', content_type = 'application/pdf')
    attachment = Mail::Part.new
    attachment.content_type = content_type
    attachment.content_disposition = "attachment; filename=#{filename}"
    attachment.content_transfer_encoding = 'base64'
    attachment.body = Base64.encode64(content)
    attachment
  end

  # Sets up an inbound email with attachments for testing
  def create_inbound_email_with_attachments(from:, to:, subject:, body:, attachments: [])
    mail = Mail.new do
      to to
      from from
      subject subject
      text_part do
        body body
      end
    end

    # Add attachments if provided
    attachments.each do |attachment|
      mail.add_part(attachment)
    end

    # Create the inbound email record
    ActionMailbox::InboundEmail.create_and_extract_message_id!(mail.to_s)
  end

  # Helper for checking if an email has been delivered
  def assert_email_delivered(to:, subject_pattern: nil)
    matching_emails = ActionMailer::Base.deliveries.select do |mail|
      mail.to.include?(to) &&
        (subject_pattern.nil? || mail.subject.match?(subject_pattern))
    end

    assert matching_emails.any?, "No email delivered to #{to} #{subject_pattern ? "with subject matching #{subject_pattern}" : ''}"
  end
end
