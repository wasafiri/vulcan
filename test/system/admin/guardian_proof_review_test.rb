# frozen_string_literal: true

require 'application_system_test_case'
require_relative '../../support/cuprite_test_bridge'

module AdminTests
  class GuardianProofReviewTest < ApplicationSystemTestCase
    include CupriteTestBridge

    setup do
      @admin = create(:admin)
      @application = create(:application, :in_progress_with_pending_proofs, :submitted_by_guardian)

      # Use enhanced sign in for better stability
      measure_time('Sign in') { enhanced_sign_in(@admin) }
      assert_text 'Dashboard', wait: 10 # Verify we're signed in with increased wait time
    end

    teardown do
      # Extra cleanup to ensure browser stability
      enhanced_sign_out if defined?(page) && page.driver.respond_to?(:browser)
    end

    test 'displays guardian alert in income proof review modal' do
      measure_time('Visit application page') do
        safe_visit admin_application_path(@application)
        wait_for_page_load
      end

      # Open the income proof review modal with safe interaction
      measure_time('Open income proof modal') do
        safe_interaction do
          find("[data-action='click->modal#open'][data-modal-id='incomeProofReviewModal']").click
          wait_for_animations
        end
      end

      # Verify the guardian alert is displayed
      measure_time('Verify guardian alert') do
        safe_interaction do
          within '#incomeProofReviewModal' do
            assert_text 'Guardian Application', wait: 5
            assert_text 'This application was submitted by a Guardian User (parent) on behalf of a dependent', wait: 5
            assert_text 'Please verify this relationship when reviewing these proof documents', wait: 5
          end
        end
      end
    end

    test 'displays guardian alert in residency proof review modal' do
      measure_time('Visit application page') do
        safe_visit admin_application_path(@application)
        wait_for_page_load
      end

      # Open the residency proof review modal with safe interaction
      measure_time('Open residency proof modal') do
        safe_interaction do
          find("[data-action='click->modal#open'][data-modal-id='residencyProofReviewModal']").click
          wait_for_animations
        end
      end

      # Verify the guardian alert is displayed
      measure_time('Verify guardian alert') do
        safe_interaction do
          within '#residencyProofReviewModal' do
            assert_text 'Guardian Application', wait: 5
            assert_text 'This application was submitted by a Guardian User (parent) on behalf of a dependent', wait: 5
            assert_text 'Please verify this relationship when reviewing these proof documents', wait: 5
          end
        end
      end
    end

    test 'does not display guardian alert for non-guardian applications' do
      # Create a regular application (not from a guardian)
      # The default constituent factory should not create a guardian or dependent under the new schema.
      regular_constituent = create(:constituent)
      regular_application = create(:application, :in_progress_with_pending_proofs, user: regular_constituent)

      measure_time('Visit regular application page') do
        safe_visit admin_application_path(regular_application)
        wait_for_page_load
      end

      # Open the income proof review modal with safe interaction
      measure_time('Open income proof modal') do
        safe_interaction do
          find("[data-action='click->modal#open'][data-modal-id='incomeProofReviewModal']").click
          wait_for_animations
        end
      end

      # Verify the guardian alert is not displayed
      measure_time('Verify no guardian alert') do
        safe_interaction do
          within '#incomeProofReviewModal' do
            assert_no_text 'Guardian Application'
            assert_no_text 'This application was submitted by a'
            assert_no_text 'on behalf of a minor'
          end
        end
      end

      # Close the modal with safe interaction
      measure_time('Close modal') do
        safe_interaction do
          find("[data-action='click->modal#close']").click
          wait_for_animations
        end
      end

      # Open the residency proof review modal with safe interaction
      measure_time('Open residency proof modal') do
        safe_interaction do
          find("[data-action='click->modal#open'][data-modal-id='residencyProofReviewModal']").click
          wait_for_animations
        end
      end

      # Verify the guardian alert is not displayed
      measure_time('Verify no guardian alert') do
        safe_interaction do
          within '#residencyProofReviewModal' do
            assert_no_text 'Guardian Application'
            assert_no_text 'This application was submitted by a'
            assert_no_text 'on behalf of a minor'
          end
        end
      end
    end
  end
end
