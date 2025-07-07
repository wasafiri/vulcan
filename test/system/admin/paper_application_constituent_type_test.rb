# frozen_string_literal: true

require 'application_system_test_case'
require_relative '../../support/cuprite_test_bridge'

module Admin
  class PaperApplicationConstituentTypeTest < ApplicationSystemTestCase
    include CupriteTestBridge
    test 'creates paper application with correct constituent type' do
      skip 'Skipping until paper application form validations are stabilized'

      # Create admin with explicitly verified status
      admin = create(:admin, verified: true)

      # Use the enhanced sign in helper
      enhanced_sign_in(admin)

      # Verify successful login by checking current path and content
      # Admins are typically redirected to the admin dashboard (applications index)
      unless current_path == root_path
        puts "DEBUG: Failed to reach admin_applications_path. Current path is #{current_path}"
        if page.has_css?('#flash .alert')
          puts "DEBUG: Flash alert message: #{find_by_id('flash').find('.alert').text}"
        elsif page.has_css?('#flash .notice')
          puts "DEBUG: Flash notice message: #{find_by_id('flash').find('.notice').text}"
        else
          puts 'DEBUG: No flash message found.'
        end
        puts "DEBUG: Page HTML: #{page.html}"
      end
      assert_current_path root_path, ignore_query: true # Redirected to home page
      assert_text "Hello, #{admin.first_name}"

      # Now visit the new paper application form
      visit new_admin_paper_application_path

      # Explicitly select the "Adult" radio button
      assert_selector 'label', text: 'An Adult (applying for themselves)' # Wait for label
      choose 'applicant_is_adult'

      # Verify the constituent section is visible
      assert_selector '#self-info-section', visible: true

      # Debug: Dump all field IDs to help identify the correct selectors
      puts "DEBUG: Current page URL: #{current_url}"

      # Print all input fields to find the actual IDs
      all_inputs = page.all('input', visible: true)
      puts "DEBUG: Found #{all_inputs.count} visible input fields:"
      all_inputs.each_with_index do |input, i|
        id_attr = input['id'].to_s
        name_attr = input['name'].to_s
        type_attr = input['type'].to_s
        puts "  #{i + 1}. ID: #{id_attr.inspect}, Name: #{name_attr.inspect}, Type: #{type_attr.inspect}"
      end

      # Get field IDs specifically from the self-application fieldset
      puts 'DEBUG: Fields in self-application fieldset:'
      within('#self-info-section') do
        fieldset_inputs = all('input, select', visible: true)
        fieldset_inputs.each_with_index do |input, i|
          id_attr = input['id'].to_s
          name_attr = input['name'].to_s
          type_attr = input['type'].to_s
          puts "  #{i + 1}. ID: #{id_attr.inspect}, Name: #{name_attr.inspect}, Type: #{type_attr.inspect}"
        end
      end

      # Now that we know the exact field IDs, let's use them to fill out the form
      # For the constituent info section, use IDs to avoid ambiguity with other sections
      fill_in 'constituent_first_name', with: 'Test'
      fill_in 'constituent_last_name', with: 'User'
      # Date of birth is required - set to 30 years ago
      fill_in 'constituent_date_of_birth', with: 30.years.ago.strftime('%Y-%m-%d')
      # Use ID for email to avoid ambiguity with medical provider email
      fill_in 'constituent_email', with: "test-system-#{Time.now.to_i}@example.com"
      fill_in 'constituent_phone', with: '2025559876'
      fill_in 'constituent_physical_address_1', with: '123 Test St'
      fill_in 'constituent_city', with: 'Baltimore'
      fill_in 'constituent_state', with: 'MD'
      fill_in 'constituent_zip_code', with: '21201'
      # Use the exact ID for the disability checkbox
      check 'applicant_attributes_cognition_disability'

      # Fill out the application form using the exact field IDs
      fill_in 'application_household_size', with: '2'
      fill_in 'application_annual_income', with: '15000'
      check 'application_maryland_resident'
      check 'applicant_attributes_self_certify_disability'

      # Medical provider fields with explicit IDs to avoid ambiguity
      fill_in 'application_medical_provider_name', with: 'Dr. Smith'
      fill_in 'application_medical_provider_phone', with: '2025551212'
      fill_in 'application_medical_provider_email', with: 'drsmith@example.com'

      # Use the simpler attach_pdf_proof helper with blank.pdf fallback
      attach_pdf_proof('income')
      choose 'accept_income_proof'

      attach_pdf_proof('residency')
      choose 'accept_residency_proof'

      # Count applications before submission
      before_count = Application.count

      # Get the email for verification
      test_email = find_field('constituent_email').value

      # Create a unique identifier for this test run to help debugging
      test_id = SecureRandom.hex(4)
      puts "TEST RUN #{test_id}: Before submission - #{before_count} applications"

      # Submit the form
      click_button 'Submit Paper Application'

      # Check if session was lost
      if page.has_text?('Signed out successfully')
        # Re-authenticate
        enhanced_sign_in(admin)
        # Don't navigate away - we should be on the application show page
      end

      # Verify we're on an application show page, not index
      assert_match %r{/admin/applications/\d+}, current_path,
                   'Should be redirected to the new application show page'

      # Verify application count increased
      assert_equal before_count + 1, Application.count,
                   'Application count should have increased by 1'

      # Find the newest application
      newest_app = Application.order(created_at: :desc).first

      # Verify it belongs to a constituent with our test email
      assert_equal test_email, newest_app.user.email,
                   'Application should be created for the test constituent'

      # Verify the constituent type
      assert_equal 'Users::Constituent', newest_app.user.type,
                   'User should be of type Constituent'

      # Optional: Verify database data using execute_script if necessary
      # constituent_email = find('dd', text: /@example.com/).text.strip
      # db_info = execute_script <<-JAVASCRIPT
      # var result = "";
      # fetch('/admin/constituents/type_check?email=#{constituent_email}', {#{' '}
      #   headers: { 'Accept': 'application/json' }#{' '}
      # })
      #   .then(response => response.json())
      #   .then(data => {
      #     document.body.setAttribute('data-check-result', JSON.stringify(data));
      #   });
      # return document.body.getAttribute('data-check-result');
      # JAVASCRIPT
      # assert db_info.present?, 'Should get DB info from API'
      # db_data = JSON.parse(db_info)
      # assert_equal 'Constituent', db_data['type'], 'Should be Constituent type'
    end

    def attach_pdf_proof(type)
      # Use an existing PDF from fixtures instead of creating one
      fixture_path = Rails.root.join('test/fixtures/files', "#{type}_proof.pdf")

      # If the specific file doesn't exist, use blank.pdf as fallback
      fixture_path = Rails.root.join('test/fixtures/files/blank.pdf') unless File.exist?(fixture_path)

      # Make sure we actually have a file to attach
      raise "Missing test fixture file: #{fixture_path}" unless File.exist?(fixture_path)

      # Attach the file to the appropriate field
      attach_file "#{type}_proof", fixture_path
    end
  end
end
