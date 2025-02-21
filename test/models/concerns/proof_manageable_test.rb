require "test_helper"

class ProofManageableTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    @application = applications(:one)
    @user = users(:constituent)
    @valid_pdf = fixture_file_upload("test/fixtures/files/valid.pdf", "application/pdf")
    @large_pdf = fixture_file_upload("test/fixtures/files/large.pdf", "application/pdf")
    @invalid_type = fixture_file_upload("test/fixtures/files/invalid.exe", "application/x-msdownload")
  end

  test "allows valid PDF uploads" do
    @application.income_proof.attach(@valid_pdf)
    assert @application.valid?
    assert @application.income_proof.attached?
  end

  test "validates file size" do
    @application.income_proof.attach(@large_pdf)
    assert_not @application.valid?
    assert_includes @application.errors[:income_proof], "is too large. Maximum size allowed is 5MB."
  end

  test "validates mime types" do
    @application.income_proof.attach(@invalid_type)
    assert_not @application.valid?
    assert_includes @application.errors[:income_proof], "must be a PDF or an image file (jpg, jpeg, png, tiff, bmp)"
  end

  test "tracks proof status changes" do
    @application.income_proof.attach(@valid_pdf)
    assert_changes -> { @application.income_proof_status }, from: "not_reviewed", to: "approved" do
      @application.update_proof_status!("income", "approved")
    end
  end

  test "creates audit trail on proof submission" do
    assert_difference "ProofSubmissionAudit.count" do
      @application.income_proof.attach(@valid_pdf)
      @application.save!
    end
  end

  test "notifies admins of new proofs" do
    assert_enqueued_with(job: NotifyAdminsJob) do
      @application.income_proof.attach(@valid_pdf)
      @application.save!
    end
  end

  test "purges proofs with audit trail" do
    @application.income_proof.attach(@valid_pdf)
    admin = users(:admin)

    assert_difference [ "Event.count", "ProofReview.count" ], 1 do
      @application.purge_proofs(admin)
    end

    assert_not @application.income_proof.attached?
    assert_equal "not_reviewed", @application.income_proof_status
  end

  test "validates both income and residency proofs independently" do
    @application.income_proof.attach(@valid_pdf)
    @application.residency_proof.attach(@invalid_type)

    assert_not @application.valid?
    assert_empty @application.errors[:income_proof]
    assert_includes @application.errors[:residency_proof], "must be a PDF or an image file (jpg, jpeg, png, tiff, bmp)"
  end

  test "handles direct uploads" do
    blob = ActiveStorage::Blob.create_before_direct_upload!(
      filename: "direct.pdf",
      byte_size: 1.megabyte,
      checksum: "dummy",
      content_type: "application/pdf"
    )

    @application.income_proof.attach(blob)
    assert @application.valid?
    assert @application.income_proof.attached?
  end

  test "sets needs_review_since on new proof submission" do
    freeze_time do
      @application.income_proof.attach(@valid_pdf)
      @application.save!
      assert_equal Time.current, @application.needs_review_since
    end
  end
end
