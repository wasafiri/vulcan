# frozen_string_literal: true

require 'test_helper'

class ApplicationNotificationsMailerTest < ActionMailer::TestCase
  include ActiveJob::TestHelper

  setup do
    @application = create(:application)
    @user = @application.user
    @proof_review = create(:proof_review, :with_income_proof, application: @application)
    @admin = create(:admin)

    # Stub URL helpers that are used in the mailer templates
    ApplicationNotificationsMailer.any_instance.stubs(:sign_in_url).returns('http://example.com/sign_in')
    ApplicationNotificationsMailer.any_instance.stubs(:login_url).returns('http://example.com/sign_in') # Alias or alternate reference
    ApplicationNotificationsMailer.any_instance.stubs(:constituent_portal_dashboard_url).returns('http://example.com/dashboard')
    ApplicationNotificationsMailer.any_instance.stubs(:new_constituent_portal_application_url).returns('http://example.com/applications/new')
    # Correctly stub the admin_applications_path to accept optional arguments
    Rails.application.routes.named_routes.path_helpers_module.define_method(:admin_applications_path) do |*args|
      '/admin/applications'
    end
    ApplicationNotificationsMailer.any_instance.stubs(:admin_application_url).with(anything, anything).returns('http://example.com/admin/applications/1')

    # Set needs_review_since for the application
    @application.update_column(:needs_review_since, 4.days.ago)

    # Set a reapply date for testing max_rejections_reached
    @reapply_date = 3.years.from_now.to_date

    # Clear emails before each test for isolation
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    # Clean up after each test
    ActionMailer::Base.deliveries.clear
  end

  test 'proof_approved' do
    email = ApplicationNotificationsMailer.proof_approved(@application, @proof_review)

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_match 'approved', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'approved'

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'approved'
  end

  test 'proof_rejected' do
    # Set up the remaining_attempts for the test
    @application.update_column(:total_rejections, 3)

    email = ApplicationNotificationsMailer.proof_rejected(@application, @proof_review)

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_match 'needs revision', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'Revision'

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'REVISION'
  end

  test 'max_rejections_reached' do
    email = ApplicationNotificationsMailer.max_rejections_reached(@application)

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@user.email], email.to
    assert_match 'Status Update', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'archived'

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'archived'
  end

  test 'proof_needs_review_reminder' do
    # Create a list of applications that need review
    applications = [@application]

    # Stub the needs_review_since method to return a date more than 3 days ago
    # This is needed for the @stale_reviews to be populated
    @application.stubs(:needs_review_since).returns(4.days.ago)

    # Use the capture_emails helper instead of assert_emails
    emails = capture_emails do
      ApplicationNotificationsMailer.proof_needs_review_reminder(@admin, applications).deliver_now
    end

    # Verify we captured exactly one email
    assert_equal 1, emails.size
    email = emails.first

    # Test email content
    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [@admin.email], email.to
    assert_match 'Awaiting Proof Review', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'Applications'

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'APPLICATIONS REQUIRING ATTENTION'
  end

  test 'account_created' do
    constituent = Constituent.create!(
      first_name: 'John',
      last_name: 'Doe',
      email: 'john.doe@example.com',
      phone: '555-123-4567',
      password: 'password',
      password_confirmation: 'password'
    )
    temp_password = 'temporary123'

    email = ApplicationNotificationsMailer.account_created(constituent, temp_password)

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal [constituent.email], email.to
    assert_match 'Your MAT Application Account', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'temporary123'
    assert_includes html_part.body.to_s, 'John'

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'temporary123'
    assert_includes text_part.body.to_s, 'John'
  end

  test 'income_threshold_exceeded' do
    constituent_params = {
      first_name: 'John',
      last_name: 'Doe',
      email: 'john.doe@example.com',
      phone: '555-123-4567'
    }

    notification_params = {
      household_size: 2,
      annual_income: 100_000,
      communication_preference: 'email',
      additional_notes: 'Income exceeds threshold'
    }

    # Set up FPL policies for testing
    Policy.find_or_create_by(key: 'fpl_2_person').update(value: 20_000)
    Policy.find_or_create_by(key: 'fpl_modifier_percentage').update(value: 400)

    email = ApplicationNotificationsMailer.income_threshold_exceeded(constituent_params, notification_params)

    assert_emails 1 do
      email.deliver_later
    end

    assert_equal ['no_reply@mdmat.org'], email.from
    assert_equal ['john.doe@example.com'], email.to
    assert_match 'Important Information About Your MAT Application', email.subject

    # Test both HTML and text parts
    assert_equal 2, email.parts.size

    # HTML part
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_includes html_part.body.to_s, 'Application Rejected'
    assert_includes html_part.body.to_s, 'John'
    assert_includes html_part.body.to_s, 'Income exceeds threshold'

    # Text part
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_includes text_part.body.to_s, 'APPLICATION REJECTED'
    assert_includes text_part.body.to_s, 'John'
    assert_includes text_part.body.to_s, 'Income exceeds threshold'
  end

  test 'registration_confirmation' do
    # Create a test constituent
    user = Constituent.create!(
      first_name: 'Jane',
      last_name: 'Smith',
      email: 'jane.smith@example.com',
      phone: '555-123-4567',
      password: 'password',
      password_confirmation: 'password',
      hearing_disability: true
    )

    # Stub Vendor.active.order to return an empty array
    active_vendors = []
    Vendor.stubs(:active).returns(Vendor.none)
    Vendor.none.stubs(:order).returns(active_vendors)

    # Verify email is delivered when we process the job
    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      perform_enqueued_jobs do
        # Generate and queue the email
        ApplicationNotificationsMailer.registration_confirmation(user).deliver_later
      end
    end

    # Get the delivered email
    email = ActionMailer::Base.deliveries.last
    assert_not_nil email, 'Email should have been delivered'

    # Test email attributes
    assert_equal ['no_reply@mdmat.org'], email.from, 'Email should be from no_reply@mdmat.org'
    assert_equal [user.email], email.to, 'Email should be sent to the registered user'
    assert_equal 'Welcome to the Maryland Accessible Telecommunications Program', email.subject

    # Verify email is multipart (HTML and text)
    assert email.multipart?, 'Email should be multipart'
    assert_equal 2, email.parts.size, 'Email should have exactly 2 parts (HTML and text)'

    # Verify HTML part exists and has correct content
    html_part = email.parts.find { |part| part.content_type.include?('text/html') }
    assert_not_nil html_part, 'HTML part should exist'
    html_content = html_part.body.to_s

    # Check for key elements in HTML content
    assert_match(/Dear Jane,/, html_content, 'Should include personalized greeting')
    assert_match(/Program Overview/, html_content, 'Should include program overview heading')
    assert_match(/Next Steps/, html_content, 'Should include next steps heading')
    assert_match(/Available Products/, html_content, 'Should include available products section')
    assert_match(/Authorized Retailers/, html_content, 'Should include authorized retailers section')
    assert_match(/iPhone, iPad, Pixel/, html_content, 'Should include smartphone examples')

    # Verify links are included but products link is removed
    assert_match(/dashboard/, html_content, 'Should include dashboard link')
    assert_match(/application/, html_content, 'Should include application link')
    assert_no_match(/browse all available products/, html_content, 'Should not include products link')

    # Verify text part exists and has correct content
    text_part = email.parts.find { |part| part.content_type.include?('text/plain') }
    assert_not_nil text_part, 'Text part should exist'
    text_content = text_part.body.to_s

    # Check for key elements in text content
    assert_match(/Dear Jane,/, text_content, 'Should include personalized greeting')
    assert_match(/PROGRAM OVERVIEW/, text_content, 'Should include program overview section')
    assert_match(/NEXT STEPS/, text_content, 'Should include next steps section')
    assert_match(/AVAILABLE PRODUCTS/, text_content, 'Should include available products section')
    assert_match(/AUTHORIZED RETAILERS/, text_content, 'Should include authorized retailers section')
    assert_match(/iPhone, iPad, Pixel/, text_content, 'Should include smartphone examples')
    assert_no_match(/browse all available products/, text_content, 'Should not include products link')
  end
end
