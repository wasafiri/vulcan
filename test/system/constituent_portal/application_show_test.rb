require "application_system_test_case"

module ConstituentPortal
  class ApplicationShowTest < ApplicationSystemTestCase
    setup do
      @constituent = users(:constituent_alex)
      sign_in(@constituent)
      @valid_pdf = file_fixture("income_proof.pdf").to_s
      @valid_image = file_fixture("residency_proof.pdf").to_s
    end

    test "application show page displays all information entered during application creation" do
      # Visit the new application page
      visit new_constituent_portal_application_path

      # Fill in all required fields
      check "I certify that I am a resident of Maryland"

      # Household information
      fill_in "Household Size", with: 3
      fill_in "Annual Income", with: 45999

      # Guardian information
      # Use JavaScript to check the guardian checkbox
      execute_script("document.getElementById('application_is_guardian').checked = true")
      execute_script("document.getElementById('application_is_guardian').dispatchEvent(new Event('change'))")
      select "Parent", from: "Relationship to Applicant"

      # Debug: Print the form values
      puts "DEBUG: Guardian checkbox checked: #{find('input#application_is_guardian').checked?}"
      puts "DEBUG: Guardian relationship selected: #{find('select#application_guardian_relationship').value}"

      # Disability information
      check "I certify that I have a disability that affects my ability to access telecommunications services"
      check "Hearing"
      check "Vision"

      # Medical provider information
      within "section[aria-labelledby='medical-info-heading']" do
        fill_in "Name", with: "Benjamin Rush"
        fill_in "Phone", with: "2022222323"
        fill_in "Email", with: "thunderbolts@rush.med"
      end

      # Upload documents
      attach_file "Proof of Residency", @valid_image, make_visible: true
      attach_file "Income Verification", @valid_pdf, make_visible: true

      # Save the application
      click_button "Save Application"

      # Verify we're redirected to the show page
      assert_text "Application saved as draft."
      assert_current_path %r{/constituent_portal/applications/\d+}

      # Debug: Print the current user's attributes
      puts "DEBUG: Current user attributes after save:"
      puts @constituent.reload.attributes.inspect

      # Debug: Print the application attributes
      current_url =~ /\/applications\/(\d+)/
      application_id = $1
      application = Application.find(application_id)
      puts "DEBUG: Application attributes after save:"
      puts application.attributes.inspect

      # Verify all entered information is displayed correctly on the show page

      # Application details
      assert_text "Status: Draft"
      assert_text "Household Size: 3"
      assert_text "Annual Income: $45,999.00"

      # Guardian information
      assert_text "Guardian Application: Yes"
      assert_text "Guardian Relationship: Parent"

      # Disability information
      assert_text "Self-Certified Disability: Yes"
      assert_text "Disability Types: Hearing, Vision"

      # Medical provider information
      assert_text "Name: Benjamin Rush"
      assert_text "Phone: 2022222323"
      assert_text "Email: thunderbolts@rush.med"

      # Uploaded documents
      assert_text "Filename: residency_proof.pdf"
      assert_text "Filename: income_proof.pdf"
    end

    test "application show page displays updated information after editing" do
      # Create a draft application first
      visit new_constituent_portal_application_path

      # Fill in required fields
      check "I certify that I am a resident of Maryland"
      fill_in "Household Size", with: 2
      fill_in "Annual Income", with: 30000
      check "I certify that I have a disability that affects my ability to access telecommunications services"
      check "Hearing"

      # Fill in medical provider info
      within "section[aria-labelledby='medical-info-heading']" do
        fill_in "Name", with: "Dr. Jane Smith"
        fill_in "Phone", with: "2025551234"
        fill_in "Email", with: "drsmith@example.com"
      end

      # Save as draft
      click_button "Save Application"

      # Verify success
      assert_text "Application saved as draft", wait: 5

      # Get the ID of the created application from the URL
      current_url =~ /\/applications\/(\d+)/
      application_id = $1

      # Visit the edit page
      visit edit_constituent_portal_application_path(application_id)

      # Update fields
      fill_in "Household Size", with: 4
      fill_in "Annual Income", with: 55000
      check "Vision"
      check "Mobility"

      # Update medical provider info
      within "section[aria-labelledby='medical-info-heading']" do
        fill_in "Name", with: "Dr. Benjamin Franklin"
        fill_in "Phone", with: "2025559876"
        fill_in "Email", with: "bfranklin@example.com"
      end

      # Debug: Print the form values
      within "section[aria-labelledby='medical-info-heading']" do
        puts "DEBUG: Medical provider name: #{find('input[name="application[medical_provider][name]"]').value}"
        puts "DEBUG: Medical provider phone: #{find('input[name="application[medical_provider][phone]"]').value}"
        puts "DEBUG: Medical provider email: #{find('input[name="application[medical_provider][email]"]').value}"
      end

      # Save the updated application
      click_button "Save Application"

      # Verify we're redirected to the show page
      assert_text "Application saved successfully."

      # Debug: Print the application attributes after update
      application = Application.find(application_id)
      puts "DEBUG: Application attributes after update:"
      puts application.attributes.inspect

      # Debug: Print the medical provider attributes
      puts "DEBUG: Medical provider attributes:"
      puts "Name: #{application.medical_provider_name}"
      puts "Phone: #{application.medical_provider_phone}"
      puts "Email: #{application.medical_provider_email}"

      # Verify updated information is displayed correctly
      assert_text "Household Size: 4"
      assert_text "Annual Income: $55,000.00"
      assert_text "Disability Types: Hearing, Vision, Mobility"
      assert_text "Name: Dr. Benjamin Franklin"
      assert_text "Phone: 2025559876"
      assert_text "Email: bfranklin@example.com"
    end
  end
end
