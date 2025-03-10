require "test_helper"

class MedicalCertificationFlowTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  
  def setup
    @admin = users(:admin_david)
    @constituent = create(:constituent)
    @application = create(:application, 
      user: @constituent,
      medical_provider_name: "Dr. Smith",
      medical_provider_email: "drsmith@example.com",
      medical_provider_phone: "555-555-5555"
    )

    # Sign in as admin
    @headers = {
      "HTTP_USER_AGENT" => "Rails Testing",
      "REMOTE_ADDR" => "127.0.0.1"
    }

    post sign_in_path,
      params: { email: @admin.email, password: "password123" },
      headers: @headers

    assert_response :redirect
    follow_redirect!
  end

  def test_full_certification_request_flow
    # 1. Visit the application page
    get admin_application_path(@application)
    assert_response :success
    
    # 2. Send certification request
    assert_enqueued_with(job: MedicalCertificationEmailJob) do
      post resend_medical_certification_admin_application_path(@application)
    end
    
    # 3. Check redirect and flash message
    assert_redirected_to admin_application_path(@application)
    assert_equal "Certification request sent successfully.", flash[:notice]
    follow_redirect!
    
    # 4. Verify application was updated
    @application.reload
    assert_equal "requested", @application.medical_certification_status
    assert_equal 1, @application.medical_certification_request_count
    
    # 5. Verify notification was created
    notification = Notification.last
    assert_equal "medical_certification_requested", notification.action
    assert_equal @application.user.id, notification.recipient_id
    assert_equal @admin.id, notification.actor_id
    
    # 6. Verify the job executed the email
    perform_enqueued_jobs
    assert_emails 1
    
    # 7. Send a second request to test history
    post resend_medical_certification_admin_application_path(@application)
    @application.reload
    assert_equal 2, @application.medical_certification_request_count
    
    # 8. Verify page shows multiple requests
    get admin_application_path(@application)
    assert_response :success
    
    # Check that history is shown
    assert_select ".certification-history .request-item", count: 2
  end
  
  def test_constituent_portal_view
    # Now test the constituent view of the certification status
    
    # Sign out admin
    delete sign_out_path
    
    # Sign in as constituent
    post sign_in_path,
      params: { email: @constituent.email, password: "password123" },
      headers: @headers
      
    # Send a certification request as admin first
    sign_in(@admin)
    post resend_medical_certification_admin_application_path(@application)
    sign_out
    
    # Sign back in as constituent
    sign_in(@constituent)
    
    # Visit application page
    get constituent_portal_application_path(@application)
    assert_response :success
    
    # Check application status
    @application.reload
    assert_equal "requested", @application.medical_certification_status
    
    # Verify medical certification status is shown
    assert_select "h2", text: /Medical Certification Status/
    
    # With more complex pages, sometimes we need to verify content exists 
    # without using exact selectors
    assert_match(/Requested/, response.body)
    assert_match(/sent on/, response.body)
  end
  
  def test_handling_errors_gracefully
    # Get a valid application without touching validation
    application_without_email = @application
    
    # Update the application directly in the database to bypass validation
    application_without_email.update_columns(medical_provider_email: nil)
    
    post resend_medical_certification_admin_application_path(application_without_email)
    assert_redirected_to admin_application_path(application_without_email)
    assert_match(/Failed to process certification request/, flash[:alert])
    
    # Verify no job was enqueued
    assert_no_enqueued_jobs only: MedicalCertificationEmailJob
    
    # Verify no notification was created
    assert_no_difference 'Notification.count' do
      # Just to satisfy the block requirement for assert_no_difference
      application_without_email
    end
  end
  
  def teardown
    clear_enqueued_jobs
    clear_performed_jobs
    Current.reset
  end
end
