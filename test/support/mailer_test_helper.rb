module MailerTestHelper
  # Helper method to stub the application needs_review_since method
  def stub_application_needs_review_since
    @application.stubs(:needs_review_since).returns(4.days.ago)
  end
end
