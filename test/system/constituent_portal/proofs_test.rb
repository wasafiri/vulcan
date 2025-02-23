require "application_system_test_case"

class ProofsSystemTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @application = applications(:one)
    @user = users(:constituent_john)

    # Create test files
    fixture_dir = Rails.root.join("test", "fixtures", "files")
    FileUtils.mkdir_p(fixture_dir)

    # Create test files if they don't exist
    [ "valid.pdf", "invalid.exe" ].each do |filename|
      file_path = fixture_dir.join(filename)
      unless File.exist?(file_path)
        File.write(file_path, "test content for #{filename}")
      end
    end

    @valid_pdf = fixture_file_upload("test/fixtures/files/valid.pdf", "application/pdf")
    @invalid_file = fixture_file_upload("test/fixtures/files/invalid.exe")

    # Ensure application has rejected proofs
    @application.update!(
      income_proof_status: :rejected,
      residency_proof_status: :rejected
    )

    # Set Current.user and sign in
    Current.user = @user
    visit sign_in_path
    assert_text "Sign In"
    fill_in "Email Address", with: @user.email
    fill_in "Password", with: "password123"
    click_button "Sign In"
    assert_text "Dashboard" # Verify we're signed in
  end

  test "resubmits rejected proof successfully" do
    # Debug output
    puts "Before visit - Application ID: #{@application.id}, Status: #{@application.income_proof_status}"
    puts "Before visit - Application exists?: #{Application.exists?(@application.id)}"
    puts "Before visit - Can submit proof?: #{@application.can_submit_proof?}"
    puts "Before visit - Valid proof type?: #{%w[income residency].include?('income')}"
    puts "Before visit - Can modify proof?: #{@application.rejected_income_proof?}"

    # Visit application page
    visit "/constituent_portal/applications/#{@application.id}"

    puts "After visit - Application exists?: #{Application.exists?(@application.id)}"
    puts "After visit - Application status: #{Application.find_by(id: @application.id)&.income_proof_status}"
    assert_text "Application Details"
    assert_text "Income Verification Status: Rejected"

    # Click resubmit button and visit proof upload page
    click_on "Resubmit Income Proof"
    assert_current_path new_proof_constituent_portal_application_path(@application, proof_type: "income")

    # Upload new proof
    attach_file "income_proof", @valid_pdf.path, make_visible: true
    click_button "Submit"

    # Verify success
    assert_text "Proof submitted successfully"
    assert_text "Income Verification Status: Not Reviewed"
  end

  test "prevents resubmitting non-rejected proofs" do
    @application.update!(income_proof_status: :not_reviewed)
    visit "/constituent_portal/applications/#{@application.id}"
    assert_text "Application Details"
    assert_no_text "Resubmit Income Proof"
  end

  test "requires authentication for proof submission" do
    click_on "Sign Out"
    visit "/constituent_portal/applications/#{@application.id}"
    assert_current_path "/sign_in"
  end

  test "shows upload form with progress bar" do
    visit "/constituent_portal/applications/#{@application.id}"
    assert_text "Application Details"
    click_on "Resubmit Income Proof"
    assert_current_path new_proof_constituent_portal_application_path(@application, proof_type: "income")

    assert_selector "h1", text: "Resubmit Income Proof"
    assert_selector "[data-upload-target='progress']"
    assert_selector "[data-upload-target='submit']"
  end

  test "handles upload errors gracefully" do
    visit "/constituent_portal/applications/#{@application.id}"
    assert_text "Application Details"
    click_on "Resubmit Income Proof"
    assert_current_path new_proof_constituent_portal_application_path(@application, proof_type: "income")

    # Attach invalid file
    attach_file "income_proof", @invalid_file.path, make_visible: true
    click_button "Submit"

    # Should show error message
    assert_text "must be a PDF or an image file"
    assert_selector ".flash.alert"
  end

  test "enforces rate limits in UI" do
    # Set up rate limit policy
    Policy.set("proof_submission_rate_limit_web", 1)
    Policy.set("proof_submission_rate_period", 1)

    visit "/constituent_portal/applications/#{@application.id}"
    assert_text "Application Details"
    click_on "Resubmit Income Proof"
    assert_current_path new_proof_constituent_portal_application_path(@application, proof_type: "income")

    # First upload should succeed
    attach_file "income_proof", @valid_pdf.path, make_visible: true
    click_button "Submit"
    assert_text "Proof submitted successfully"

    # Try second upload
    visit "/constituent_portal/applications/#{@application.id}"
    assert_text "Application Details"
    click_on "Resubmit Income Proof"
    assert_current_path new_proof_constituent_portal_application_path(@application, proof_type: "income")
    attach_file "income_proof", @valid_pdf.path, make_visible: true
    click_button "Submit"
    assert_text "Please wait before submitting another proof"
  end

  test "shows file size limit in UI" do
    visit "/constituent_portal/applications/#{@application.id}"
    assert_text "Application Details"
    click_on "Resubmit Income Proof"
    assert_current_path new_proof_constituent_portal_application_path(@application, proof_type: "income")
    assert_text "Maximum size allowed is 5MB"
  end

  test "maintains accessibility during upload" do
    visit "/constituent_portal/applications/#{@application.id}"
    assert_text "Application Details"
    click_on "Resubmit Income Proof"
    assert_current_path new_proof_constituent_portal_application_path(@application, proof_type: "income")

    # Form should be accessible
    assert_selector "label[for='income_proof']"
    assert_selector "[aria-label='Upload progress']"
    assert_selector "button[type='submit']"

    # Attach file
    attach_file "income_proof", @valid_pdf.path, make_visible: true

    # Progress information should be announced
    assert_selector "[role='progressbar']"
    assert_selector "[aria-live='polite']"
  end
end
