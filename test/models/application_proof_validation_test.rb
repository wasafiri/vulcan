require "test_helper"

class ApplicationProofValidationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionDispatch::TestProcess::FixtureFile

  setup do
    @application = create(:application, :in_progress)
    @valid_pdf = fixture_file_upload("test/fixtures/files/valid.pdf", "application/pdf")
    @valid_image = fixture_file_upload("test/fixtures/files/valid.jpg", "image/jpeg")

    # Create test files if they don't exist
    fixture_dir = Rails.root.join("test", "fixtures", "files")
    FileUtils.mkdir_p(fixture_dir)

    [ "valid.pdf", "valid.jpg" ].each do |filename|
      file_path = fixture_dir.join(filename)
      unless File.exist?(file_path)
        File.write(file_path, "test content for #{filename}")
      end
    end
  end

  test "validates income proof file type" do
    # Valid file types
    @application.income_proof.attach(@valid_pdf)
    assert @application.valid?

    @application.income_proof.detach
    @application.income_proof.attach(@valid_image)
    assert @application.valid?

    # Invalid file type
    invalid_file = fixture_file_upload("test/fixtures/files/invalid.exe", "application/octet-stream")

    # Create invalid file if it doesn't exist
    unless File.exist?(fixture_dir.join("invalid.exe"))
      File.write(fixture_dir.join("invalid.exe"), "test content for invalid.exe")
    end

    @application.income_proof.detach
    @application.income_proof.attach(invalid_file)
    assert_not @application.valid?
    assert_includes @application.errors.full_messages.to_sentence, "must be a PDF or an image file"
  end

  test "validates income proof file size" do
    # Create a large file that exceeds the size limit
    large_file_path = fixture_dir.join("large_file.pdf")

    # Skip this test if we can't create a large file
    begin
      # Create a 6MB file (assuming 5MB limit)
      File.open(large_file_path, "wb") do |f|
        f.write("0" * (6 * 1024 * 1024))
      end

      large_file = fixture_file_upload("test/fixtures/files/large_file.pdf", "application/pdf")
      @application.income_proof.attach(large_file)
      assert_not @application.valid?
      assert_includes @application.errors.full_messages.to_sentence, "must be less than 5MB"
    ensure
      # Clean up
      File.delete(large_file_path) if File.exist?(large_file_path)
    end
  end

  test "validates residency proof shows address" do
    # This is a business rule that would need custom validation
    # For now, we're just testing that the file can be attached
    @application.residency_proof.attach(@valid_image)
    assert @application.valid?
  end

  test "resets proof status when new proof is attached" do
    # First set the status to rejected
    @application.update!(income_proof_status: :rejected)

    # Then attach a new proof
    @application.income_proof.attach(@valid_pdf)
    @application.save!

    # Status should be reset to not_reviewed
    assert_equal "not_reviewed", @application.reload.income_proof_status
  end

  test "sets needs_review_since when proof status changes to not_reviewed" do
    # First set the status to rejected
    @application.update!(income_proof_status: :rejected, needs_review_since: nil)

    # Then attach a new proof
    @application.income_proof.attach(@valid_pdf)
    @application.save!

    # needs_review_since should be set
    assert_not_nil @application.reload.needs_review_since
  end

  test "notifies admins when proof needs review" do
    assert_enqueued_with(job: NotifyAdminsJob) do
      @application.update!(
        income_proof_status: :not_reviewed,
        needs_review_since: Time.current
      )
    end
  end

  test "validates SSA award letter is current year" do
    # This would require custom validation logic in the model
    # For now, we're just documenting the requirement
    skip "Implement custom validation for SSA award letter date"
  end

  test "validates SSA award letter is less than 2 months old" do
    # This would require custom validation logic in the model
    # For now, we're just documenting the requirement
    skip "Implement custom validation for SSA award letter age"
  end
end
