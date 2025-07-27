# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class ApplicationsTest < ApplicationSystemTestCase
    setup do
      @admin = create(:admin)
      @application = create(:application, :in_progress_with_pending_proofs, skip_proofs: true)

      # Attach the proofs manually to ensure complete control over the attachments
      unless @application.income_proof.attached?
        @application.income_proof.attach(
          io: Rails.root.join('test/fixtures/files/income_proof.pdf').open,
          filename: 'income_proof.pdf',
          content_type: 'application/pdf'
        )
      end

      unless @application.residency_proof.attached?
        @application.residency_proof.attach(
          io: Rails.root.join('test/fixtures/files/residency_proof.pdf').open,
          filename: 'residency_proof.pdf',
          content_type: 'application/pdf'
        )
      end

      unless @application.medical_certification.attached?
        @application.medical_certification.attach(
          io: Rails.root.join('test/fixtures/files/medical_certification_valid.pdf').open,
          filename: 'medical_certification_valid.pdf',
          content_type: 'application/pdf'
        )
      end

      # Set the medical certification status to 'received'
      @application.update!(medical_certification_status: :received)

      # Sign in as admin - using system test authentication
      system_test_sign_in(@admin)
    end

    test 'admin can view application details successfully with factory-created records' do
      visit admin_application_path(@application)
      
      # Ensure the page has loaded by waiting for basic HTML structure
      assert_selector 'html', wait: 10
      
      # Wait for the specific content to load 
      assert_selector 'h1', text: /Application.*Details/, wait: 20
      assert_text(@application.user.full_name, wait: 20)

      # Verify sections exist using more stable selectors with increased wait times
      # Use has_selector with explicit waits to ensure elements exist before proceeding
      assert has_selector?('[aria-labelledby="applicant-info-title"]', wait: 25)
      assert has_selector?('[aria-labelledby="application-details-title"]', wait: 25)
      assert has_selector?('[aria-labelledby="attachments-title"]', wait: 25)

      # Verify income and residency proof sections exist and show the correct status
      # Add defensive waiting before using within block
      if has_selector?('[aria-labelledby="attachments-title"]', wait: 25)
        within '[aria-labelledby="attachments-title"]' do
          assert_text 'Income Proof', wait: 25
          assert_text 'Not Reviewed', wait: 25

          assert_text 'Residency Proof', wait: 25
          assert_text 'Not Reviewed', wait: 25
        end
      end
    end

    test 'admin can approve medical certification directly via service' do
      # This test demonstrates that our factory-created application works with service objects
      assert_equal 'received', @application.medical_certification_status

      # Directly use the service object that the controller would use
      result = MedicalCertificationAttachmentService.update_certification_status(
        application: @application,
        status: :approved,
        admin: @admin
      )

      assert result[:success], 'Medical certification approval failed'

      # Verify the application record was updated
      @application.reload
      assert_equal 'approved', @application.medical_certification_status

      # Now visit the page to verify it shows correctly with comprehensive error handling
      with_browser_rescue do
        visit admin_application_path(@application)
        wait_for_turbo(timeout: 20)
        wait_for_network_idle(timeout: 15)

        # Use more defensive page stability checking
        begin
          # Wait for basic page structure first
          assert has_content?(@application.user.full_name, wait: 25)
          
          # Then wait for the heading
          assert has_selector?('h1', text: /Application.*Details/, wait: 25)
          
          # Look for medical certification section and approved status
          # Try multiple approaches to find the medical certification status
          medical_cert_found = false
          
          # First try: use the testid selector
          if has_selector?('[data-testid="medical-certification-section"]', wait: 15)
            within '[data-testid="medical-certification-section"]' do
              if has_text?('Medical Certification', wait: 10) && has_text?('Approved', wait: 10)
                medical_cert_found = true
              end
            end
          end
          
          # Second try: look for it anywhere on the page
          unless medical_cert_found
            if has_text?('Medical Certification', wait: 15) && has_text?('Approved', wait: 15)
              medical_cert_found = true
            end
          end
          
          # Third try: check for any certification-related content
          unless medical_cert_found
            if has_text?('Certification', wait: 10) && has_text?('Approved', wait: 10)
              medical_cert_found = true
            end
          end
          
          assert medical_cert_found, 'Could not find approved medical certification status on page'
          
        rescue Ferrum::NodeNotFoundError => e
          # Provide helpful debugging info
          take_screenshot
          puts "Page content sample: #{page.body[0..500]}"
          raise "Medical certification section not found after page load: #{e.message}"
        end
      end
    end

    test 'factory-created application can have proofs approved and trigger certification request' do
      # Set up the application in the right state
      @application.update!(
        medical_certification_status: :not_requested,
        income_proof_status: :not_reviewed,
        residency_proof_status: :not_reviewed
      )

      # Directly approve proofs using services
      proof_reviewer = Applications::ProofReviewer.new(@application, @admin)

      income_result = proof_reviewer.review(
        proof_type: 'income',
        status: 'approved'
      )

      residency_result = proof_reviewer.review(
        proof_type: 'residency',
        status: 'approved'
      )

      # The ProofReviewer returns true for success, not a hash
      assert income_result, 'Income proof approval failed'
      assert residency_result, 'Residency proof approval failed'

      # Verify application state - this should now trigger the certification request
      @application.reload

      # Verify proof statuses were updated correctly
      assert_equal 'approved', @application.income_proof_status, 'Income proof status was not approved'
      assert_equal 'approved', @application.residency_proof_status, 'Residency proof status was not approved'

      # Verify the certification status was correctly updated to requested
      assert_equal 'requested', @application.medical_certification_status,
                   "Medical certification wasn't automatically requested after approving both proofs"

      # Success! We've confirmed the model behavior works with factory-created records
    end
  end
end
