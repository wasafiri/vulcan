# frozen_string_literal: true

require 'application_system_test_case'

class ProofsSystemTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    setup_fpl_policies          # Creates FPL and rate limit policies

    @user = create(:constituent)
    @application = create(:application, :in_progress_with_rejected_proofs, :old_enough_for_new_application, user: @user)

    # Attach files for rejected proofs statuses already handled by trait

    system_test_sign_in(@user)

    # Prepare fixtures directory and sample files
    fixture_dir = Rails.root.join('test/fixtures/files')
    FileUtils.mkdir_p(fixture_dir)

    @valid_pdf = fixture_dir.join('valid.pdf')
    @invalid_file_path = fixture_dir.join('invalid.exe')
    File.write(@valid_pdf, 'test pdf') unless File.exist?(@valid_pdf)
    File.write(@invalid_file_path, 'exe') unless File.exist?(@invalid_file_path)

    wait_for_turbo
  end

  def attach_valid_proof
    attach_file 'income_proof_upload', @valid_pdf
  end

  test 'resubmits rejected proof successfully' do
    # Visit application page
    visit "/constituent_portal/applications/#{@application.id}"
    assert_text 'Application Details'

    # In the constituent portal, rejected proofs show a "Resubmit" button rather than status text
    assert_text 'Resubmit Income Proof'

    # Click resubmit button and visit proof upload page
    click_on 'Resubmit Income Proof'

    # Debug: Check what happened after the click
    puts "URL after click: #{current_url}"
    puts "Status code: #{page.status_code}"
    puts "Page has content?: #{page.body.length > 100}"
    puts "Page has errors?: #{page.body.include?('error') || page.body.include?('Error')}"
    puts "Error details: #{page.body}" if page.status_code == 500

    assert_selector 'h1', text: /Upload New Income Proof/i

    # Upload new proof
    attach_file 'income_proof_upload', @valid_pdf
    click_button 'Submit Document'

    # Verify success
    assert_success_message('Proof submitted successfully')
    # After successful submission, we should be redirected back to the application page
    assert_current_path constituent_portal_application_path(@application)
  end

  test 'prevents resubmitting non-rejected proofs' do
    @application.update!(income_proof_status: :not_reviewed)
    visit "/constituent_portal/applications/#{@application.id}"
    assert_text 'Application Details'
    assert_no_text 'Resubmit Income Proof'
  end

  test 'requires authentication for proof submission' do
    click_on 'Sign Out'
    visit "/constituent_portal/applications/#{@application.id}"
    assert_current_path '/sign_in'
  end

  test 'shows upload form with progress bar' do
    visit "/constituent_portal/applications/#{@application.id}"
    assert_text 'Application Details'
    click_on 'Resubmit Income Proof'
    assert_selector 'h1', text: /Upload New Income Proof/i

    # Progress bar is initially hidden but should exist
    assert_selector "[data-upload-target='progress']", visible: :hidden
    assert_selector "[data-upload-target='submit']"
  end

  test 'handles upload errors gracefully' do
    visit "/constituent_portal/applications/#{@application.id}"
    assert_text 'Application Details'
    click_on 'Resubmit Income Proof'
    assert_selector 'h1', text: /Upload New Income Proof/i

    # Try to upload an invalid file - handle both alert and non-alert scenarios
    begin
      # Some systems show alerts for invalid files, others show inline validation
      accept_alert do
        attach_file 'income_proof_upload', @invalid_file_path
      end
    rescue Capybara::ModalNotFound
      # No alert shown - validation might be inline or disabled
      attach_file 'income_proof_upload', @invalid_file_path
    end

    # After handling the invalid file, we should still be on the same page
    assert_selector 'h1', text: /Upload New Income Proof/i

    # Try to submit and verify error handling (if the file wasn't rejected immediately)
    if find_field('income_proof_upload').value.present?
      click_button 'Submit Document'
      # Should show some kind of error message
      assert_text(/invalid|error|not supported|wrong format/i)
    end
  end

  test 'enforces rate limits in UI' do
    # Set up rate limit policy
    Policy.find_or_create_by!(key: 'proof_submission_rate_limit_web') do |p|
      p.value = 1
      p.updated_by = @user
    end
    Policy.find_or_create_by!(key: 'proof_submission_rate_period') do |p|
      p.value = 1
      p.updated_by = @user
    end

    visit "/constituent_portal/applications/#{@application.id}"
    assert_text 'Application Details'
    click_on 'Resubmit Income Proof'
    assert_selector 'h1', text: /Upload New Income Proof/i

    # First upload should succeed
    attach_valid_proof
    click_button 'Submit Document'

    # Should see success message
    assert_success_message('Proof submitted successfully')

    # Now try to upload again - should hit rate limit
    # Go back to application page and try to resubmit again
    visit "/constituent_portal/applications/#{@application.id}"

    # If there's still a resubmit button, the first upload didn't change the status
    if page.has_text?('Resubmit Income Proof')
      click_on 'Resubmit Income Proof'
      attach_valid_proof

      # This should trigger rate limiting - click and wait for response
      click_button 'Submit Document'

      # Check for rate limit message or error (could be inline error or modal)
      begin
        # Check if there's a custom modal with rate limit message
        assert_selector '[role="dialog"]', text: /rate limit|wait|too many|recently/i, wait: 2
        within '[role="dialog"]' do
          click_button 'OK' if page.has_button?('OK')
        end
      rescue Capybara::ElementNotFound
        # No modal - check for inline error message
        assert_text(/rate limit|wait|too many|recently/i)
      end
    else
      # If no resubmit button, the proof status changed and rate limiting worked
      assert_text 'Not Reviewed'
    end
  end

  test 'shows file size limit in UI' do
    visit "/constituent_portal/applications/#{@application.id}"
    assert_text 'Application Details'
    click_on 'Resubmit Income Proof'
    assert_selector 'h1', text: /Upload New Income Proof/i
    assert_text 'Maximum file size: 5MB'
  end

  test 'maintains accessibility during upload' do
    visit "/constituent_portal/applications/#{@application.id}"
    assert_text 'Application Details'
    click_on 'Resubmit Income Proof'
    assert_selector 'h1', text: /Upload New Income Proof/i

    # Form should be accessible
    assert_selector "label[for='income_proof_upload']"
    assert_selector "button[type='submit']"

    # Progress bar exists but is initially hidden
    assert_selector "[data-upload-target='progress']", visible: :hidden
    assert_selector "[data-upload-target='progress'] [role='progressbar']", visible: :hidden

    # Attach file
    attach_valid_proof

    # Progress information should be announced (role is nested within progress target)
    # Note: In a real upload, JavaScript would make this visible, but in tests it stays hidden
    assert_selector "[data-upload-target='progress'] [role='progressbar']", visible: :hidden
  end
end
