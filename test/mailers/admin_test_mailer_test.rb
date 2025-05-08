# frozen_string_literal: true

require 'test_helper'

class AdminTestMailerTest < ActionMailer::TestCase
  setup do
    @admin = create(:admin)
    @template_name = 'application_notifications_account_created'
    @subject = 'Test Email Subject'
    @body = 'This is a test email body for template testing.'
  end

  test 'test_email with text format' do
    # Prepare mail parameters
    params = {
      user: @admin,
      recipient_email: @admin.email,
      template_name: @template_name,
      subject: @subject,
      body: @body,
      format: 'text'
    }

    # Generate the email
    email = nil
    assert_emails 1 do
      email = AdminTestMailer.with(params).test_email
      email.deliver_now
    end

    # Check basic email properties
    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@admin.email], email.to
    assert_equal "[TEST] #{@subject} (Template: #{@template_name})", email.subject

    # Check content
    assert_equal "#{@body}", email.body.to_s.strip
  end

  test 'test_email respects custom recipient_email' do
    custom_email = 'test.recipient@example.com'

    # Prepare mail parameters
    params = {
      user: @admin,
      recipient_email: custom_email, # Use custom email address
      template_name: @template_name,
      subject: @subject,
      body: @body,
      format: 'text'
    }

    # Generate the email
    email = nil
    assert_emails 1 do
      email = AdminTestMailer.with(params).test_email
      email.deliver_now
    end

    # Check that it's sent to the custom recipient
    assert_equal [custom_email], email.to
  end

  test 'test_email falls back to user email if recipient_email is nil' do
    # Prepare mail parameters
    params = {
      user: @admin,
      recipient_email: nil, # Explicitly nil
      template_name: @template_name,
      subject: @subject,
      body: @body,
      format: 'text'
    }

    # Generate the email
    email = nil
    assert_emails 1 do
      email = AdminTestMailer.with(params).test_email
      email.deliver_now
    end

    # Check that it falls back to the user's email
    assert_equal [@admin.email], email.to
  end

  test 'test_email converts format to symbol' do
    # Prepare mail parameters with string format
    params = {
      user: @admin,
      template_name: @template_name,
      subject: @subject,
      body: @body,
      format: 'text' # String format
    }

    # Generate the email
    email = AdminTestMailer.with(params).test_email

    # Since we can't directly test that params[:format] was converted to a symbol,
    # we can check that the email was generated correctly
    # Use assert_includes because content_type may include charset info (e.g., 'text/plain; charset=UTF-8')
    assert_includes email.content_type, 'text/plain'
  end
end
