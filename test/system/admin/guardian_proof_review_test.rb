# frozen_string_literal: true

require 'application_system_test_case'

module AdminTests
  class GuardianProofReviewTest < ApplicationSystemTestCase
    setup do
      # Force a clean browser session for each test
      Capybara.reset_sessions!

      @admin = create(:admin)
      @application = create(:application, :in_progress_with_pending_proofs, :submitted_by_guardian, :old_enough_for_new_application)

      # Don't sign in during setup - let each test handle its own authentication
      # This ensures each test starts with a clean authentication state
    end

    teardown do
      # Ensure any open modals are closed
      begin
        if has_selector?('#incomeProofReviewModal', visible: true)
          within('#incomeProofReviewModal') do
            click_button 'Close' if has_button?('Close')
          end
        end

        if has_selector?('#residencyProofReviewModal', visible: true)
          within('#residencyProofReviewModal') do
            click_button 'Close' if has_button?('Close')
          end
        end
      rescue Ferrum::NodeNotFoundError, Ferrum::DeadBrowserError
        # Browser might be in a bad state, reset it
        Capybara.reset_sessions!
      end

      # Always ensure clean session state between tests
      Capybara.reset_sessions!
    end

    test 'displays guardian alert in income proof review modal' do
      # Always sign in fresh for each test
      system_test_sign_in(@admin)
      visit admin_application_path(@application)

      # Wait for page to load completely
      assert_selector 'h1#application-title', wait: 15

      # Use intelligent waiting - assert_selector will wait automatically
      assert_selector '#attachments-section', wait: 15
      assert_selector '#attachments-section', text: 'Income Proof'
      assert_selector '#attachments-section', text: 'Residency Proof'

      # Open the income proof review modal
      within '#attachments-section' do
        # Find the specific button for income proof with explicit wait
        assert_selector('button[data-modal-id="incomeProofReviewModal"]', wait: 15)
        find('button[data-modal-id="incomeProofReviewModal"]', wait: 15).click
      end

      # Verify the guardian alert is displayed - use have_content for intelligent waiting
      within '#incomeProofReviewModal' do
        assert_content 'Guardian Application'
        assert_content 'This application was submitted by a Guardian User (parent) on behalf of a dependent'
        assert_content 'Please verify this relationship when reviewing these proof documents'

        # Close the modal to prevent interference with subsequent tests
        click_button 'Close'
      end
    end

    test 'displays guardian alert in residency proof review modal' do
      # Always sign in fresh for each test
      system_test_sign_in(@admin)
      visit admin_application_path(@application)

      # Wait for page to load completely
      assert_selector 'h1#application-title', wait: 15

      # Use intelligent waiting - assert_selector will wait automatically
      assert_selector '#attachments-section', wait: 15
      assert_selector '#attachments-section', text: 'Income Proof'
      assert_selector '#attachments-section', text: 'Residency Proof'

      # Open the residency proof review modal
      within '#attachments-section' do
        # Find the specific button for residency proof with explicit wait
        assert_selector('button[data-modal-id="residencyProofReviewModal"]', wait: 15)
        find('button[data-modal-id="residencyProofReviewModal"]', wait: 10).click
      end

      # Verify the guardian alert is displayed - use have_content for intelligent waiting
      within '#residencyProofReviewModal' do
        assert_content 'Guardian Application'
        assert_content 'This application was submitted by a Guardian User (parent) on behalf of a dependent'
        assert_content 'Please verify this relationship when reviewing these proof documents'

        # Close the modal to prevent interference with subsequent tests
        click_button 'Close'
      end
    end

    test 'does not display guardian alert for non-guardian applications' do
      # Always sign in fresh for each test
      system_test_sign_in(@admin)

      # Create a regular application (not from a guardian) with all required fields
      regular_constituent = create(:constituent,
                                   email: "regular_test_#{Time.now.to_i}_#{rand(10_000)}@example.com",
                                   first_name: 'Regular',
                                   last_name: 'User')
      regular_application = create(:application,
                                   :in_progress_with_pending_proofs,
                                   :old_enough_for_new_application,
                                   user: regular_constituent,
                                   household_size: 2,
                                   annual_income: 30_000,
                                   maryland_resident: true,
                                   self_certify_disability: true)

      # Manually attach proofs since the factory trait isn't working
      regular_application.income_proof.attach(
        io: Rails.root.join('test/fixtures/files/medical_certification_valid.pdf').open,
        filename: 'income_proof.pdf',
        content_type: 'application/pdf'
      )
      regular_application.residency_proof.attach(
        io: Rails.root.join('test/fixtures/files/medical_certification_valid.pdf').open,
        filename: 'residency_proof.pdf',
        content_type: 'application/pdf'
      )

      # Ensure proofs are properly saved and processed
      regular_application.reload

      visit admin_application_path(regular_application)

      # Wait for basic page structure first
      assert_selector 'body', wait: 5

      # Wait for page to load completely with intelligent waiting
      # Use a more specific selector that indicates the page has fully loaded
      assert_selector 'h1#application-title', wait: 15

      # Use intelligent waiting - assert_selector will wait automatically
      assert_selector '#attachments-section', wait: 15
      assert_selector '#attachments-section', text: 'Income Proof'
      assert_selector '#attachments-section', text: 'Residency Proof'

      # Open the income proof review modal
      within '#attachments-section' do
        find('button[data-modal-id="incomeProofReviewModal"]').click
      end

      # Verify the guardian alert is not displayed - use has_no_content for intelligent waiting
      within '#incomeProofReviewModal' do
        assert_no_content 'Guardian Application'
        assert_no_content 'This application was submitted by a'
        assert_no_content 'on behalf of a minor'
      end

      # Close the modal
      within '#incomeProofReviewModal' do
        click_button 'Close'
      end

      # Open the residency proof review modal
      within '#attachments-section' do
        find('button[data-modal-id="residencyProofReviewModal"]').click
      end

      # Verify the guardian alert is not displayed
      within '#residencyProofReviewModal' do
        assert_no_content 'Guardian Application'
        assert_no_content 'This application was submitted by a'
        assert_no_content 'on behalf of a minor'
      end
    end
  end
end
