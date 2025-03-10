require 'application_system_test_case'

module AdminTests
  class MedicalCertificationTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_david)
      @application = applications(:submitted_application)
      
      # Set up medical provider details
      @application.update!(
        medical_provider_name: 'Good Health Clinic',
        medical_provider_phone: '555-123-4567',
        medical_provider_email: 'provider@goodhealthclinic.com'
      )

      # Skip test in CI environment
      if ENV['CI']
        skip 'Medical certification tests are not configured for CI yet'
      end

      # Sign in as admin
      sign_in(@admin)
    end

    test 'medical certification section displays correctly' do
      # Make sure it's set to not_requested for this test
      @application.update!(medical_certification_status: :not_requested)
      
      visit admin_application_path(@application)

      # Find the medical certification section (now standalone section)
      assert_selector '[data-testid="medical-certification-section"] h2', text: 'Medical Certification'
      
      # Check for provider information
      within('[data-testid="medical-certification-section"]') do
        # Provider info subsection
        assert_selector 'h3', text: 'Provider Information'
        assert_text 'Good Health Clinic'
        assert_text 'Phone: 555-123-4567'
        assert_text 'Email: provider@goodhealthclinic.com'
        
        # Status badge should be present
        assert_selector 'span.rounded-full', text: 'Not Requested'
      end
    end

    test 'medical certification request button functions correctly' do
      # Set the certification status to not requested
      @application.update!(medical_certification_status: :not_requested)
      
      visit admin_application_path(@application)
      
      within('[data-testid="medical-certification-section"]') do
        # Certification status subsection
        assert_selector 'h3', text: 'Certification Status'
        
        # Status should be displayed
        assert_selector 'span.rounded-full', text: 'Not Requested'
        
        # Send request button should be present in the action section
        assert_button 'Send Request'
      end
      
      # Test clicking the button (would need to mock the post request)
      # accept_confirm do
      #   click_button 'Send Request'
      # end
      # assert_text 'Request sent successfully'
    end

    test 'medical certification review button appears when certification is received' do
      # Set up medical certification as received
      @application.update!(medical_certification_status: :received)
      
      # Attach a file as the medical certification
      unless @application.medical_certification.attached?
        @application.medical_certification.attach(
          io: File.open(Rails.root.join('test/fixtures/files/income_proof.pdf')),
          filename: 'medical_certification.pdf',
          content_type: 'application/pdf'
        )
      end
      
      visit admin_application_path(@application)
      
      within('[data-testid="medical-certification-section"]') do
        # Status should be received
        assert_selector 'span.rounded-full', text: 'Received'
        
        # Review button should be present
        assert_button 'Review Certification'
      end
      
      # Test modal behavior
      # click_button 'Review Certification'
      # within '#medicalCertificationReviewModal' do
      #   assert_text 'Review Medical Certification'
      #   assert_button 'Approve'
      #   assert_button 'Reject'
      # end
    end

    test 'view certification button appears when certification is approved' do
      # Set up medical certification as approved
      @application.update!(
        medical_certification_status: :accepted,
        medical_certification_verified_at: Time.current,
        medical_certification_verified_by: @admin
      )
      
      # Attach a file as the medical certification
      unless @application.medical_certification.attached?
        @application.medical_certification.attach(
          io: File.open(Rails.root.join('test/fixtures/files/income_proof.pdf')),
          filename: 'medical_certification.pdf',
          content_type: 'application/pdf'
        )
      end
      
      visit admin_application_path(@application)
      
      within('[data-testid="medical-certification-section"]') do
        # Status should be approved
        assert_selector 'span.rounded-full', text: 'Accepted'
        
        # Certification status subsection
        within('[data-testid="certification-status"]') do
          # Should show who verified and when
          assert_text 'Certified on'
          assert_text @admin.full_name
        end
        
        # View button should be present
        assert_selector 'a', text: 'View Certification'
      end
    end

    test 'rejected certification shows rejection reason' do
      # Set up medical certification as rejected
      @application.update!(
        medical_certification_status: :rejected,
        medical_certification_rejection_reason: 'The certification is incomplete.'
      )
      
      visit admin_application_path(@application)
      
      within('[data-testid="medical-certification-section"]') do
        # Status should be rejected
        assert_selector 'span.rounded-full', text: 'Rejected'
        
        # Certification status subsection
        within('[data-testid="certification-status"]') do
          # Rejection reason should be displayed
          assert_text 'Reason:'
          assert_text 'The certification is incomplete.'
        end
        
        # Send request button should be present
        assert_button 'Send Request'
      end
    end
    
    test 'certification history modal displays request history' do
      # Create some notifications for the medical certification requests
      @notification1 = Notification.create!(
        notifiable: @application,
        action: 'medical_certification_requested',
        actor: @admin,
        recipient: @application.user,
        created_at: 2.days.ago
      )
      
      @notification2 = Notification.create!(
        notifiable: @application,
        action: 'medical_certification_requested',
        actor: @admin,
        recipient: @application.user,
        created_at: 1.day.ago
      )
      
      visit admin_application_path(@application)
      
      within('[data-testid="medical-certification-section"]') do
        # History button should be present
        assert_button 'View History'
        click_button 'View History'
      end
      
      # Check modal content
      within '#viewCertificationHistoryModal' do
        assert_text 'Medical Certification Request History'
        assert_text 'Request #1'
        assert_text 'Request #2' 
        assert_text 'Most Recent'
        assert_text @admin.full_name
      end
    end
  end
end
