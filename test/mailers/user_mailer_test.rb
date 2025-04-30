# frozen_string_literal: true

require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  # Helper to create mock templates that performs interpolation
  def mock_template(subject_format, body_format)
    template = mock('email_template')
    # Stub render to accept keyword args and perform interpolation
    template.stubs(:render).with(any_parameters).returns do |**vars|
      rendered_subject = subject_format % vars
      rendered_body = body_format % vars
      [rendered_subject, rendered_body]
    end
    template
  end

  setup do
    # Stubs for specific templates - Use correct names matching the mailer and use mock_template helper
    EmailTemplate.stubs(:find_by!).with(name: 'user_mailer_password_reset',
                                        format: :html).returns(mock_template('Reset your password',
                                                                             '<p>HTML Body with %<reset_url>s</p>'))
    EmailTemplate.stubs(:find_by!).with(name: 'user_mailer_password_reset',
                                        format: :text).returns(mock_template('Reset your password',
                                                                             'Text Body with %<reset_url>s'))
    EmailTemplate.stubs(:find_by!).with(name: 'user_mailer_email_verification',
                                        format: :html).returns(mock_template('Verify your email',
                                                                             '<p>HTML Body with %<verification_url>s</p>'))
    EmailTemplate.stubs(:find_by!).with(name: 'user_mailer_email_verification',
                                        format: :text).returns(mock_template('Verify your email',
                                                                             'Text Body with %<verification_url>s'))

    @user = create(:user)
    # Stub token generation to return predictable values for testing
    # This is needed because the application might not have explicitly set up
    # generates_token_for with these specific purposes
    @user.stubs(:generate_token_for).with(:password_reset).returns('test-password-reset-token')
    @user.stubs(:generate_token_for).with(:email_verification).returns('test-email-verification-token')

    # Stub the URL helpers that our mailer uses
    UserMailer.any_instance.stubs(:edit_password_url).returns('http://example.com/password/edit?token=test-password-reset-token')
    UserMailer.any_instance.stubs(:verify_constituent_portal_application_url).returns('http://example.com/constituent_portal/applications/verify?token=test-email-verification-token')
  end

  test 'password_reset' do
    # Using Rails 7.1.0+ capture_emails helper
    emails = capture_emails do
      UserMailer.with(user: @user).password_reset.deliver_now
    end

    # Verify we captured an email
    assert_equal 1, emails.size
    email = emails.first

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_match 'Reset your password', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part - Assert against specific mock body content
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'http://example.com/password/edit?token=test-password-reset-token'

    # Text part - Assert against specific mock body content
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'http://example.com/password/edit?token=test-password-reset-token'
  end

  test 'email_verification' do
    # Using Rails 7.1.0+ capture_emails helper
    emails = capture_emails do
      UserMailer.with(user: @user).email_verification.deliver_now
    end

    # Verify we captured an email
    assert_equal 1, emails.size
    email = emails.first

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_match 'Verify your email', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part - Assert against specific mock body content
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'http://example.com/constituent_portal/applications/verify?token=test-email-verification-token'

    # Text part - Assert against specific mock body content
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'http://example.com/constituent_portal/applications/verify?token=test-email-verification-token'
  end
end
