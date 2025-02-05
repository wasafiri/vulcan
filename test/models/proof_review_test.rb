require "test_helper"

class ProofReviewTest < ActiveSupport::TestCase
  def setup
    @admin = users(:admin_david)
    @application = create(:application, :in_progress)
  end

  def test_valid_proof_review
    proof_review = build(:proof_review,
      application: @application,
      admin: @admin,
      proof_type: :income,
      status: :approved,
      reviewed_at: Time.current
    )

    assert proof_review.valid?
  end

  def test_invalid_without_required_fields
    proof_review = ProofReview.new
    assert_not proof_review.valid?

    assert_includes proof_review.errors[:proof_type], "can't be blank"
    assert_includes proof_review.errors[:status], "can't be blank"
    assert_includes proof_review.errors[:admin], "must be present"
    assert_includes proof_review.errors[:application], "must be present"
  end

  def test_requires_rejection_reason_when_rejected
    proof_review = build(:proof_review,
      application: @application,
      admin: @admin,
      proof_type: :income,
      status: :rejected,
      rejection_reason: nil
    )

    assert_not proof_review.valid?
    assert_includes proof_review.errors[:rejection_reason], "can't be blank"
  end

  def test_updates_application_status_when_proof_is_approved
    @application.update!(income_proof_status: :not_reviewed)

    create(:proof_review,
      application: @application,
      admin: @admin,
      proof_type: :income,
      status: :approved
    )

    @application.reload
    assert @application.income_proof_status_approved?
  end

  def test_archives_application_after_max_rejections
    @application.update!(total_rejections: 8)

    create(:proof_review,
      application: @application,
      admin: @admin,
      proof_type: :income,
      status: :rejected,
      rejection_reason: "Final rejection"
    )

    @application.reload
    assert @application.archived?
  end

  def test_prevents_review_of_archived_application
    application = create(:application, :archived)

    proof_review = build(:proof_review,
      application: application,
      admin: @admin,
      proof_type: :income,
      status: :approved
    )

    assert_not proof_review.valid?
    assert_includes proof_review.errors[:application],
                    "cannot be reviewed when archived"
  end

  def test_sends_notification_on_proof_rejection
    assert_difference "Notification.count" do
      create(:proof_review,
        application: @application,
        admin: @admin,
        proof_type: :income,
        status: :rejected,
        rejection_reason: "Invalid documentation"
      )
    end
  end
end
