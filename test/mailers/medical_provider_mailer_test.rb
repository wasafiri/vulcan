require "test_helper"

class MedicalProviderMailerTest < ActionMailer::TestCase
  def setup
    # Create application with all required fields for medical provider notification
    @application = create(:application, :in_progress_with_approved_proofs,
      medical_provider_name: "Dr. Smith",
      medical_provider_email: "dr.smith@example.com",
      medical_provider_phone: "555-555-0000",
      medical_provider_fax: "555-555-0001"
    )
  end

  def test_request_certification
    # Verify email generation and delivery
    email = MedicalProviderMailer.request_certification(@application)

    # Test email delivery
    assert_emails 1 do
      email.deliver_now
    end

    # Test email content
    assert_equal [ @application.medical_provider_email ], email.to
    assert_equal "Disability Certification Request for #{@application.user.full_name}",
                 email.subject

    # Test email body includes required information
    body = email.html_part.body.to_s
    assert_match @application.user.full_name, body
    assert_match @application.medical_provider_name, body
    assert_match @application.id.to_s, body
  end

  def teardown
    # Clean up any created files or records
    DatabaseCleaner.clean
  end
end
