require "application_system_test_case"

class Admin::PaperApplicationConstituentTypeTest < ApplicationSystemTestCase
  test "creates paper application with correct constituent type" do
    # Log in as admin
    admin = users(:admin_david)
    sign_in_as(admin)

    # Visit the new paper application form
    visit new_admin_paper_application_path

    # Fill out the constituent form
    fill_in "constituent[first_name]", with: "Test"
    fill_in "constituent[last_name]", with: "User"
    fill_in "constituent[email]", with: "test-system-#{Time.now.to_i}@example.com"
    fill_in "constituent[phone]", with: "2025559876"
    fill_in "constituent[physical_address_1]", with: "123 Test St"
    fill_in "constituent[city]", with: "Baltimore"
    fill_in "constituent[state]", with: "MD"
    fill_in "constituent[zip_code]", with: "21201"
    check "constituent[cognition_disability]"
    
    # Fill out the application form
    fill_in "application[household_size]", with: "2"
    fill_in "application[annual_income]", with: "15000"
    check "application[maryland_resident]"
    check "application[self_certify_disability]"
    fill_in "application[medical_provider_name]", with: "Dr. Smith"
    fill_in "application[medical_provider_phone]", with: "2025551212"
    fill_in "application[medical_provider_email]", with: "drsmith@example.com"
    
    # Attach files
    attach_pdf_proof("income")
    select "Accept", from: "income_proof_action"
    
    attach_pdf_proof("residency")
    select "Accept", from: "residency_proof_action"
    
    # Submit the form
    click_button "Submit Paper Application"
    
    # Expect to be redirected to the application show page
    assert_current_path(/\/admin\/applications\/\d+/)
    
    # Verify the success message
    assert_text "Paper application successfully submitted"
    
    # Verify the correct type is shown in the details
    assert_text "Constituent" # This should show the constituent type
    
    # Open Rails console to verify the record uses the correct class
    constituent_email = find("dd", text: /@example.com/).text.strip
    
    # Check database data using execute_script
    db_info = execute_script <<-JAVASCRIPT
      var result = "";
      fetch('/admin/constituents/type_check?email=#{constituent_email}', { 
        headers: { 'Accept': 'application/json' } 
      })
        .then(response => response.json())
        .then(data => {
          document.body.setAttribute('data-check-result', JSON.stringify(data));
        });
      return document.body.getAttribute('data-check-result');
    JAVASCRIPT
    
    assert db_info.present?, "Should get DB info from API"
    db_data = JSON.parse(db_info)
    assert_equal "Constituent", db_data["type"], "Should be Constituent type"
  end
  
  private
  
  def sign_in_as(user)
    visit sign_in_path
    fill_in "Email", with: user.email
    fill_in "Password", with: "password" # Assuming this is the fixture password
    click_button "Sign in"
    assert_text "Signed in successfully"
  end
  
  def attach_pdf_proof(type)
    # Create and attach a simple PDF for testing
    pdf_path = Rails.root.join("tmp", "#{type}_proof.pdf")
    unless File.exist?(pdf_path)
      File.open(pdf_path, "w") do |f|
        f.write("%PDF-1.7\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << >> /Contents 4 0 R >>\nendobj\n4 0 obj\n<< >>\nstream\nBT /F1 12 Tf 100 700 Td (Test PDF) Tj ET\nendstream\nendobj\nxref\n0 5\n0000000000 65535 f\n0000000010 00000 n\n0000000059 00000 n\n0000000118 00000 n\n0000000217 00000 n\ntrailer\n<< /Size 5 /Root 1 0 R >>\nstartxref\n280\n%%EOF")
      end
    end
    
    # Attach the file to the appropriate field
    attach_file "#{type}_proof", pdf_path
  end
end
