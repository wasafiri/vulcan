# frozen_string_literal: true

require 'application_system_test_case'
require_relative '../../support/cuprite_test_bridge'

module Admin
  class PaperApplicationDependentGuardianTest < ApplicationSystemTestCase
    include CupriteTestBridge

    test 'creates paper application for dependent with new guardian creation flow' do
      # Create admin with explicitly verified status
      admin = create(:admin, verified: true)

      # Use the enhanced sign in helper
      enhanced_sign_in(admin)

      # Navigate to paper application form
      visit new_admin_paper_application_path

      # Step 1: Select "A Dependent" radio button
      assert_selector 'label', text: 'A Dependent (must select existing guardian in system or enter guardian\'s information)'
      choose 'applicant_is_minor'

      # Step 2: Verify Guardian Information section becomes visible
      assert_selector '#guardian-info-section', visible: true
      assert_text 'Guardian Information'

      # Step 3: Verify Dependent Information section is initially hidden
      assert_selector '#dependent-info-section', visible: false

      # Step 4: Fill out guardian creation form
      within '#guardian-info-section' do
        # Ensure we're in the "Create new guardian" tab
        click_on 'Create new guardian' if page.has_link?('Create new guardian')

        # Fill guardian form
        fill_in 'guardian_attributes[first_name]', with: 'Guardian'
        fill_in 'guardian_attributes[last_name]', with: 'TestParent'
        fill_in 'guardian_attributes[date_of_birth]', with: 40.years.ago.strftime('%Y-%m-%d')
        fill_in 'guardian_attributes[email]', with: "guardian-test-#{Time.now.to_i}@example.com"
        fill_in 'guardian_attributes[phone]', with: '5551234567'
        fill_in 'guardian_attributes[physical_address_1]', with: '456 Guardian Ave'
        fill_in 'guardian_attributes[city]', with: 'Baltimore'
        select 'MD', from: 'guardian_attributes[state]'
        fill_in 'guardian_attributes[zip_code]', with: '21202'
        choose 'guardian_attributes_phone_type_mobile'
        choose 'guardian_attributes_communication_preference_email'

        # Step 5: Click "Save Guardian" and verify creation
        click_button 'Save Guardian'

        # Wait for guardian creation to complete
        assert_text 'Guardian TestParent', wait: 5
      end

      # Step 6: Verify Dependent Information section becomes visible after guardian creation
      assert_selector '#dependent-info-section', visible: true, wait: 5
      assert_text 'Dependent Information'

      # Step 7: Fill out dependent information
      # NOTE: This test covers the scenario where dependent has their own email (email_strategy: 'dependent')
      within '#dependent-info-section' do
        fill_in 'constituent[first_name]', with: 'Dependent'
        fill_in 'constituent[last_name]', with: 'TestChild'
        fill_in 'constituent[date_of_birth]', with: 10.years.ago.strftime('%Y-%m-%d')
        fill_in 'constituent[dependent_email]', with: "dependent-test-#{Time.now.to_i}@example.com"

        # Select email strategy (dependent has their own email)
        choose 'email_strategy_dependent'

        # Select relationship type
        select 'Child', from: 'relationship_type'

        # Add disability information
        check 'constituent[hearing_disability]'
      end

      # Step 8: Fill out application details
      fill_in 'application_household_size', with: '3'
      fill_in 'application_annual_income', with: '25000'
      check 'application_maryland_resident'
      check 'applicant_attributes_self_certify_disability'

      # Medical provider information
      fill_in 'application_medical_provider_name', with: 'Dr. Pediatric'
      fill_in 'application_medical_provider_phone', with: '5555551234'
      fill_in 'application_medical_provider_email', with: 'drpediatric@example.com'

      # Attach required proofs
      attach_pdf_proof('income')
      choose 'accept_income_proof'

      attach_pdf_proof('residency')
      choose 'accept_residency_proof'

      # Step 9: Submit the application
      before_count = Application.count
      before_user_count = User.count
      before_relationship_count = GuardianRelationship.count

      click_button 'Submit Paper Application'

      # Step 10: Verify successful submission
      assert_match %r{/admin/applications/\d+}, current_path,
                   'Should be redirected to the new application show page'

      # Step 11: Verify database changes
      assert_equal before_count + 1, Application.count,
                   'Application count should have increased by 1'

      assert_equal before_user_count + 2, User.count,
                   'User count should have increased by 2 (guardian + dependent)'

      assert_equal before_relationship_count + 1, GuardianRelationship.count,
                   'Guardian relationship count should have increased by 1'

      # Step 12: Verify the application structure
      newest_app = Application.order(created_at: :desc).first

      # Application should belong to the dependent
      assert_equal 'Users::Constituent', newest_app.user.type,
                   'Application user should be a Constituent'
      assert newest_app.user.first_name.include?('Dependent'),
             'Application should belong to the dependent user'

      # Step 13: Verify guardian relationship was created
      guardian_relationship = GuardianRelationship.order(created_at: :desc).first
      assert_equal newest_app.user, guardian_relationship.dependent,
                   'Guardian relationship dependent should match application user'
      assert guardian_relationship.guardian.first_name.include?('Guardian'),
             'Guardian relationship should have the correct guardian'
      assert_equal 'child', guardian_relationship.relationship_type,
                   'Relationship type should be set correctly'
    end

    test 'shows validation errors when guardian creation fails' do
      admin = create(:admin, verified: true)
      enhanced_sign_in(admin)
      visit new_admin_paper_application_path

      # Select dependent option
      choose 'applicant_is_minor'

      # Try to create guardian with missing required fields
      within '#guardian-info-section' do
        click_on 'Create new guardian' if page.has_link?('Create new guardian')

        # Leave required fields empty and try to submit
        fill_in 'guardian_attributes[first_name]', with: ''
        fill_in 'guardian_attributes[email]', with: 'invalid-email'

        click_button 'Save Guardian'

        # Should show validation errors without submitting
        assert_selector '.border-red-500', count: 2, wait: 3
      end

      # Dependent section should still be hidden since guardian wasn't created
      assert_selector '#dependent-info-section', visible: false
    end

    test 'allows selecting existing guardian instead of creating new one' do
      # Create an existing guardian
      create(:constituent,
             first_name: 'Existing',
             last_name: 'Guardian',
             email: 'existing.guardian@example.com')

      admin = create(:admin, verified: true)
      enhanced_sign_in(admin)
      visit new_admin_paper_application_path

      # Select dependent option
      choose 'applicant_is_minor'

      # Search for existing guardian
      within '#guardian-info-section' do
        fill_in 'Search guardians...', with: 'Existing'

        # Wait for search results
        assert_text 'Existing Guardian', wait: 5

        # Select the existing guardian
        click_on 'Select Guardian'
      end

      # Dependent section should become visible
      assert_selector '#dependent-info-section', visible: true, wait: 5
    end

    test 'preserves guardian selection after creation' do
      admin = create(:admin, verified: true)
      enhanced_sign_in(admin)
      visit new_admin_paper_application_path

      # Select dependent option
      choose 'applicant_is_minor'

      # Create a guardian
      within '#guardian-info-section' do
        click_on 'Create new guardian' if page.has_link?('Create new guardian')

        fill_in 'guardian_attributes[first_name]', with: 'Selected'
        fill_in 'guardian_attributes[last_name]', with: 'Guardian'
        fill_in 'guardian_attributes[date_of_birth]', with: 40.years.ago.strftime('%Y-%m-%d')
        fill_in 'guardian_attributes[email]', with: "selected-guardian-#{Time.now.to_i}@example.com"
        fill_in 'guardian_attributes[phone]', with: '5559876543'
        fill_in 'guardian_attributes[physical_address_1]', with: '789 Test Lane'
        fill_in 'guardian_attributes[city]', with: 'Baltimore'
        select 'MD', from: 'guardian_attributes[state]'
        fill_in 'guardian_attributes[zip_code]', with: '21203'

        click_button 'Save Guardian'

        # Verify guardian is displayed as selected
        assert_text 'Selected Guardian', wait: 5
      end

      # Verify the search form is hidden and selected guardian is shown
      assert_selector '.guardian-search-form', visible: false
      assert_selector '.guardian-details-container', visible: true
      assert_text 'Selected Guardian'

      # Dependent section should be visible
      assert_selector '#dependent-info-section', visible: true
    end

    private

    def attach_pdf_proof(type)
      fixture_path = Rails.root.join('test/fixtures/files', "#{type}_proof.pdf")
      fixture_path = Rails.root.join('test/fixtures/files/blank.pdf') unless File.exist?(fixture_path)

      raise "Missing test fixture file: #{fixture_path}" unless File.exist?(fixture_path)

      attach_file "#{type}_proof", fixture_path
    end
  end
end
