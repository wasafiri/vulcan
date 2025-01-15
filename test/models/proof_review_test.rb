require "test_helper"

class ProofReviewTest < ActiveSupport::TestCase
  setup do
    @admin = create(:admin)
    @application = create(:application)
    @proof_review = create(:proof_review, :approved)  # Assuming you have a proof_review factory
  end

  test "valid proof review" do
    proof_review = ProofReview.new(
      application: @application,
      admin: @admin,
      proof_type: :income,
      status: :approved,
      reviewed_at: Time.current
    )
    assert proof_review.valid?
  end

  test "invalid without required fields" do
    proof_review = ProofReview.new
    assert_not proof_review.valid?
    assert_not_nil proof_review.errors[:proof_type]
    assert_not_nil proof_review.errors[:status]
    assert_not_nil proof_review.errors[:admin]
    assert_not_nil proof_review.errors[:application]
  end

  test "requires rejection reason when rejected" do
    proof_review = ProofReview.new(
      application: @application,
      admin: @admin,
      proof_type: :income,
      status: :rejected,
      reviewed_at: Time.current
    )
    assert_not proof_review.valid?
    assert_not_nil proof_review.errors[:rejection_reason]
  end

  test "updates application status when proof is approved" do
    @application.update!(income_proof_status: :not_reviewed)

    ProofReview.create!(
      application: @application,
      admin: @admin,
      proof_type: :income,
      status: :approved
    )

    assert_equal "approved", @application.reload.income_proof_status
  end

  test "archives application after max rejections" do
    @application.update!(total_rejections: 8)

    ProofReview.create!(
      application: @application,
      admin: @admin,
      proof_type: :income,
      status: :rejected,
      rejection_reason: "Final rejection"
    )

    assert @application.reload.archived?
  end

  test "prevents review of archived application" do
    @application.update!(status: :archived)

    proof_review = ProofReview.new(
      application: @application,
      admin: @admin,
      proof_type: :income,
      status: :approved
    )

    assert_not proof_review.valid?
    assert_includes proof_review.errors[:application], "cannot be reviewed when archived"
  end
end
