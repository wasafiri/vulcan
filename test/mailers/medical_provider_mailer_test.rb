require "test_helper"

class MedicalProviderMailerTest < ActionMailer::TestCase
  def setup
    @application = create(:application, :in_progress) # Use factory instead of fixture
  end

  test "request_certification" do
    email = MedicalProviderMailer.request_certification(@application)
    assert_emails 1 do
      email.deliver_now
    end
    assert_equal [ @application.medical_provider_email ], email.to
    assert_equal "Disability Certification Request for #{@application.user.full_name}",
                 email.subject
    assert_match @application.user.full_name, email.html_part.body.to_s
  end
end
