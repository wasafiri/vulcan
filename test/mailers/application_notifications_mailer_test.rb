require "test_helper"

class ApplicationNotificationsMailerTest < ActionMailer::TestCase
  setup do
    @application = applications(:one)
    @user = @application.user
    @proof_review = proof_reviews(:income_approved)
    @admin = users(:admin_david)

    # Set needs_review_since for the application
    @application.update_column(:needs_review_since, 4.days.ago)

    # Set a reapply date for testing max_rejections_reached
    @reapply_date = 3.years.from_now.to_date
  end

  test "proof_approved" do
    email = ApplicationNotificationsMailer.proof_approved(@application, @proof_review)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "info@mdmat.org" ], email.from
    assert_equal [ @user.email ], email.to
    assert_match "approved", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_includes html_part.body.to_s, "approved"

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_includes text_part.body.to_s, "approved"
  end

  test "proof_rejected" do
    # Set up the remaining_attempts for the test
    @application.update_column(:total_rejections, 3)

    email = ApplicationNotificationsMailer.proof_rejected(@application, @proof_review)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "info@mdmat.org" ], email.from
    assert_equal [ @user.email ], email.to
    assert_match "needs revision", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_includes html_part.body.to_s, "Revision"

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_includes text_part.body.to_s, "REVISION"
  end

  test "max_rejections_reached" do
    email = ApplicationNotificationsMailer.max_rejections_reached(@application)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "info@mdmat.org" ], email.from
    assert_equal [ @user.email ], email.to
    assert_match "Status Update", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_includes html_part.body.to_s, "archived"

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_includes text_part.body.to_s, "archived"
  end

  test "proof_needs_review_reminder" do
    # Create a list of applications that need review
    applications = [ @application ]

    # Stub the needs_review_since method to return a date more than 3 days ago
    # This is needed for the @stale_reviews to be populated
    @application.stubs(:needs_review_since).returns(4.days.ago)

    email = ApplicationNotificationsMailer.proof_needs_review_reminder(@admin, applications)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "info@mdmat.org" ], email.from
    assert_equal [ @admin.email ], email.to
    assert_match "Awaiting Proof Review", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_includes html_part.body.to_s, "Applications"

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_includes text_part.body.to_s, "APPLICATIONS REQUIRING ATTENTION"
  end

  test "account_created" do
    constituent = Constituent.create!(
      first_name: "John",
      last_name: "Doe",
      email: "john.doe@example.com",
      phone: "555-123-4567",
      password: "password",
      password_confirmation: "password"
    )
    temp_password = "temporary123"

    email = ApplicationNotificationsMailer.account_created(constituent, temp_password)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "info@mdmat.org" ], email.from
    assert_equal [ constituent.email ], email.to
    assert_match "Your MAT Application Account", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_includes html_part.body.to_s, "temporary123"
    assert_includes html_part.body.to_s, "John"

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_includes text_part.body.to_s, "temporary123"
    assert_includes text_part.body.to_s, "John"
  end

  test "income_threshold_exceeded" do
    constituent_params = {
      first_name: "John",
      last_name: "Doe",
      email: "john.doe@example.com",
      phone: "555-123-4567"
    }

    notification_params = {
      household_size: 2,
      annual_income: 100000,
      notification_method: "email",
      additional_notes: "Income exceeds threshold"
    }

    # Set up FPL policies for testing
    Policy.find_or_create_by(key: "fpl_2_person").update(value: 20000)
    Policy.find_or_create_by(key: "fpl_modifier_percentage").update(value: 400)

    email = ApplicationNotificationsMailer.income_threshold_exceeded(constituent_params, notification_params)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ "info@mdmat.org" ], email.from
    assert_equal [ "john.doe@example.com" ], email.to
    assert_match "Important Information About Your MAT Application", email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_includes html_part.body.to_s, "Application Rejected"
    assert_includes html_part.body.to_s, "John"
    assert_includes html_part.body.to_s, "Income exceeds threshold"

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_includes text_part.body.to_s, "APPLICATION REJECTED"
    assert_includes text_part.body.to_s, "John"
    assert_includes text_part.body.to_s, "Income exceeds threshold"
  end
end
