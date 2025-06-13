# frozen_string_literal: true

module ActionMailboxTestHelper
  def self.included(base)
    base.class_eval do
      require 'action_mailbox/test_helper'
      include ActionMailbox::TestHelper
    end
  end

  # Assert that an email would be routed to the expected mailbox
  #
  # @param mailbox_class [Class] The mailbox you expect to match
  # @param kwargs        Mail attributes (:to, :from, :subject, etc.)
  #
  def assert_mailbox_routed(mailbox_class, **kwargs)
    mail = Mail.new({ to: 'nobody@example.com',
                      from: 'test@example.com' }.merge(kwargs))

    inbound_email = create_inbound_email_from_source(mail.to_s)

    routed_mailbox = ApplicationMailbox.router.mailbox_for(inbound_email)

    assert_equal mailbox_class, routed_mailbox,
                 "Expected message #{kwargs.inspect} to route to #{mailbox_class}, " \
                 "but it was routed to #{routed_mailbox || 'nothing'}"
  end

  # Helper to create an inbound email without attachments
  def create_inbound_email_from_attributes(to:, from:, subject: 'Test Email', body: 'Test Body')
    mail = Mail.new do
      to to
      from from
      subject subject
      body body
    end

    ActionMailbox::InboundEmail.create_and_extract_message_id!(mail.to_s)
  end

  # Helper to create an inbound email with attachments
  def create_inbound_email_with_attachment(to:, from:, subject:, body:, attachment_path:, content_type:)
    file = File.read(attachment_path)
    mail = Mail.new do
      to to
      from from
      subject subject

      text_part do
        body body
      end

      add_file filename: File.basename(attachment_path), content: file,
               content_type: content_type
    end

    ActionMailbox::InboundEmail.create_and_extract_message_id!(mail.to_s)
  end

  # This method is expected by the tests but was missing
  def receive_inbound_email_from_mail(to:, from:, subject: 'Test Email', body: 'Test Body', attachments: nil)
    mail = Mail.new do
      to to
      from from
      subject subject

      if attachments.nil?
        body body
      else
        text_part do
          body body
        end

        attachments.each do |attachment|
          add_file(
            filename: attachment[:filename],
            content: attachment[:content],
            content_type: attachment[:content_type]
          )
        end
      end
    end

    inbound_email = ActionMailbox::InboundEmail.create_and_extract_message_id!(mail.to_s)
    inbound_email.route
    inbound_email
  end
end
