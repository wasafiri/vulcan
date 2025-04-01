# frozen_string_literal: true

require 'application_system_test_case'
require 'support/system_test_authentication'

module Admin
  class MedicalCertificationApprovalTest < ApplicationSystemTestCase
    include SystemTestAuthentication

    setup do
      @admin = users(:admin)
      @application = applications(:active)
      sign_in @admin
    end

    test 'admin can approve and upload medical certification' do
      visit admin_application_path(@application)

      # Verify the upload form is present
      assert_selector 'h3', text: 'Upload Faxed Medical Certification'
      
      # Select approve option and attach file
      find('input[value="accepted"]').click
      attach_file('medical_certification', Rails.root.join('test/fixtures/files/medical_certification_valid.pdf'))
      
      # Submit the form
      click_button 'Process Certification'
      
      # Assert success message
      assert_text 'Medical certification successfully uploaded and approved'
      
      # Verify the certification was attached
      assert @application.reload.medical_certification.attached?
      assert_equal 'accepted', @application.medical_certification_status
    end
    
    test 'admin can reject medical certification with reason' do
      visit admin_application_path(@application)
      
      # Select reject option
      find('input[value="rejected"]').click
      
      # Select rejection reason and add notes
      select 'Missing Information', from: 'medical_certification_rejection_reason'
      fill_in 'medical_certification_rejection_notes', with: 'The form is missing required patient information.'
      
      # Submit the form
      click_button 'Process Certification'
      
      # Assert success message
      assert_text 'Medical certification rejected and provider notified'
      
      # Verify the certification was rejected
      assert_equal 'rejected', @application.reload.medical_certification_status
    end
    
    test 'admin must select a file when approving' do
      visit admin_application_path(@application)
      
      # Select approve option but don't attach a file
      find('input[value="accepted"]').click
      
      # Submit the form
      click_button 'Process Certification'
      
      # Assert error message
      assert_text 'Please select a file to upload'
    end
    
    test 'admin must select a rejection reason when rejecting' do
      visit admin_application_path(@application)
      
      # Select reject option but don't select a reason
      find('input[value="rejected"]').click
      
      # Submit the form
      click_button 'Process Certification'
      
      # Assert error message
      assert_text 'Please select a rejection reason'
    end
  end
end
