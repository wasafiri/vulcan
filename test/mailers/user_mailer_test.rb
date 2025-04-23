# frozen_string_literal: true

require 'test_helper'

class UserMailerTest < ActionMailer::TestCase
  setup do
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

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'password'
    assert_includes html_part.body.to_s, 'reset'
    assert_includes html_part.body.to_s, 'test-password-reset-token'

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'password'
    assert_includes text_part.body.to_s, 'reset'
    assert_includes text_part.body.to_s, 'test-password-reset-token'
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

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'verify'
    assert_includes html_part.body.to_s, 'email'
    assert_includes html_part.body.to_s, 'test-email-verification-token'

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'verify'
    assert_includes text_part.body.to_s, 'email'
    assert_includes text_part.body.to_s, 'test-email-verification-token'
  end
end
