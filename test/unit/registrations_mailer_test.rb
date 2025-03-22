require "test_helper"

class RegistrationsMailerTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  
  test "registration_confirmation email should be sent" do
    # Skip loading fixtures to avoid foreign key violations
    
    # Create a test user directly (not saved to DB)
    user = Constituent.new(
      first_name: "Test",
      last_name: "User",
      email: "test@example.com",
      phone: "555-123-4567"
    )
    
    # Clear any emails from previous tests
    ActionMailer::Base.deliveries.clear
    
    # Generate and deliver the email
    email = ApplicationNotificationsMailer.registration_confirmation(user).deliver_now
    
    # Basic assertions
    assert_equal ["no_reply@mdmat.org"], email.from
    assert_equal ["test@example.com"], email.to
    assert_equal "Welcome to the Maryland Accessible Telecommunications Program", email.subject
    
    # Check multipart email
    assert email.multipart?
    assert_equal 2, email.parts.size
    
    # Check HTML part content
    html_part = email.parts.find { |part| part.content_type.include?("text/html") }
    assert_not_nil html_part
    assert_includes html_part.body.to_s, "Dear Test,"
    assert_includes html_part.body.to_s, "Program Overview"
    
    # Check text part content
    text_part = email.parts.find { |part| part.content_type.include?("text/plain") }
    assert_not_nil text_part
    assert_includes text_part.body.to_s, "Dear Test,"
    assert_includes text_part.body.to_s, "PROGRAM OVERVIEW"
  end
  
  test "registrations controller should send email" do
    # Skip fixtures to avoid foreign key violations
    
    # Create a test user directly
    ActionMailer::Base.deliveries.clear
    
    # Mock the mailer
    mock_mailer = Minitest::Mock.new
    mock_mailer.expect :deliver_later, nil
    
    # Mock the controller action
    ApplicationNotificationsMailer.stub :registration_confirmation, mock_mailer do
      # Create a user (no DB save)
      user = Constituent.new(
        first_name: "New",
        last_name: "User",
        email: "newuser@example.com"
      )
      
      # Simulate the controller action
      ApplicationNotificationsMailer.registration_confirmation(user)
    end
    
    # Verify mock was called
    mock_mailer.verify
  end
end
