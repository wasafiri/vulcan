# test/models/application_test.rb
require "test_helper"

class ApplicationTest < ActiveSupport::TestCase
  test "notifies admins when proofs need review" do
    application = create(:application)  # Use factory instead of fixture
    admin_count = User.where(type: "Admin").count

    assert_difference "Notification.count", admin_count do
      application.update!(
        income_proof_status: :not_reviewed,
        needs_review_since: Time.current
      )
    end
  end

  test "contacts medical provider when all proofs approved" do
    application = create(:application)  # Use factory instead of fixture

    assert_enqueued_email_with MedicalProviderMailer, :request_certification do
      create(:proof_review,
        application: application,
        admin: create(:admin),
        proof_type: :income,
        status: :approved
      )
    end
  end
end
