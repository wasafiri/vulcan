require "application_system_test_case"

class MedicalCertificationTest < ApplicationSystemTestCase
  # Split up tests into smaller, focused tests with less complex interactions
  # to avoid timeouts and browser issues
  
  def setup
    super
    
    # Create admin, constituent and application
    @admin = users(:admin_david)
    @constituent = create(:constituent)
    @application = create(:application, 
      user: @constituent,
      medical_provider_name: "Dr. Jane Smith",
      medical_provider_email: "drsmith@example.com",
      medical_provider_phone: "555-555-5555"
    )
  end

  # Test 1: Simple test that just verifies the certification section exists in admin view
  test "admin can view medical certification section" do
    safe_browser_action do
      sign_in(@admin)
      visit admin_application_path(@application)
      wait_for_complete_page_load
      
      # Verify the section exists
      assert_text "Medical Certification Status"
      
      # Verify medical provider info is displayed
      assert_text @application.medical_provider_name
      assert_text @application.medical_provider_phone
    end
  end
  
  # Test 2: Test sending a certification request
  test "admin can send medical certification request" do
    safe_browser_action do
      sign_in(@admin)
      visit admin_application_path(@application)
      wait_for_complete_page_load
      
      # Send certification request
      safe_accept_alert do
        if page.has_button?("Send Request")
          click_button "Send Request" 
        else
          click_button "Resend Request"
        end
      end
      
      # Wait for page to load
      wait_for_complete_page_load
      
      # Verify flash message and history
      assert_text "Certification request sent successfully"
      
      # Verify request history is displayed
      assert_selector ".certification-history", count: 1
      assert_text "Request 1 sent on"
    end
  end
  
  # Test 3: A separate test for viewing as a constituent
  test "constituent can view certification status" do
    # Setup - Create a notification without browser interaction
    notification = Notification.create!(
      notifiable: @application, 
      recipient: @constituent,
      actor: @admin,
      action: "medical_certification_requested",
      created_at: 1.hour.ago,
      read_at: nil
    )
    
    # Update application status without browser interaction
    @application.update!(
      medical_certification_status: "requested",
      medical_certification_request_count: 1
    )
    
    safe_browser_action do
      # Sign in as constituent
      sign_in(@constituent)
      
      # Visit application page
      visit constituent_portal_application_path(@application)
      wait_for_complete_page_load
      
      # Verify medical certification section is shown
      assert_text "Medical Certification Status"
      
      # Verify medical provider info is displayed
      assert_text @application.medical_provider_name
      
      # Verify certification status
      assert_selector ".certification-status", text: "Requested"
    end
  end
  
  # Test 4: Error case in a separate test
  test "admin sees appropriate error for invalid requests" do
    # Update application directly in DB to remove email
    @application.update_columns(medical_provider_email: nil)
    
    safe_browser_action do
      # Sign in as admin
      sign_in(@admin)
      
      # Visit application show page
      visit admin_application_path(@application)
      wait_for_complete_page_load
      
      # Try to send request
      safe_accept_alert do
        if page.has_button?("Send Request")
          click_button "Send Request" 
        else
          click_button "Resend Request"
        end
      end
      wait_for_complete_page_load
      
      # Verify error message
      assert_text "Failed to process certification request"
    end
  end
  
  def teardown
    # Clean up any jobs in the queue
    clear_enqueued_jobs
    clear_performed_jobs
    
    # Call parent teardown which handles browser cleanup
    super
  end
end
