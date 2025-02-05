require "test_helper"

class ApplicationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  def setup
    @admin = users(:admin_david)
    @application = create(:application, :in_progress)
    @proof_review = build(:proof_review,
      application: @application,
      admin: @admin
    )
  end

  test "notifies admins when proofs need review" do
    assert_enqueued_with(job: NotifyAdminsJob) do
      @application.update!(
        income_proof_status: :not_reviewed,
        needs_review_since: Time.current
      )
    end
  end

  test "contacts medical provider when all proofs approved" do
    application = create(:application, :in_progress_with_rejected_proofs)

    assert_enqueued_with(
      job: ActionMailer::MailDeliveryJob,
      args: [
        "MedicalProviderMailer",
        "request_certification",
        "deliver_now",
        { args: [ application ] }
      ]
    ) do
      create(:proof_review,
        application: application,
        admin: @admin,
        proof_type: :income,
        status: :approved
      )
      create(:proof_review,
        application: application,
        admin: @admin,
        proof_type: :residency,
        status: :approved
      )
    end

    application.reload
    assert application.all_proofs_approved?
  end
end
