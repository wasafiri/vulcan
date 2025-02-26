require "test_helper"

class UserMailerTest < ActionMailer::TestCase
  setup do
    @user = users(:one)
  end

  test "password_reset" do
    email = UserMailer.with(user: @user).password_reset

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "info@mdmat.org" ], email.from
    assert_equal [ @user.email ], email.to
    assert_match "Reset your password", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_includes html_part.body.to_s, "password"
    assert_includes html_part.body.to_s, "reset"

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_includes text_part.body.to_s, "password"
    assert_includes text_part.body.to_s, "reset"
  end

  test "email_verification" do
    email = UserMailer.with(user: @user).email_verification

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "info@mdmat.org" ], email.from
    assert_equal [ @user.email ], email.to
    assert_match "Verify your email", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_includes html_part.body.to_s, "verify"
    assert_includes html_part.body.to_s, "email"

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_includes text_part.body.to_s, "verify"
    assert_includes text_part.body.to_s, "email"
  end
end
