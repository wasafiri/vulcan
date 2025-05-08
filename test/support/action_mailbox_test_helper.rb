# frozen_string_literal: true

module ActionMailboxTestHelper
  # Helper to create an inbound email without attachments
  def create_inbound_email_from_mail(to:, from:, subject: 'Test Email', body: 'Test Body')
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
