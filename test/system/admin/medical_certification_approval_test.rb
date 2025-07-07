# frozen_string_literal: true

require 'application_system_test_case'
require 'support/system_test_authentication'

module Admin
  class MedicalCertificationApprovalTest < ApplicationSystemTestCase
    include SystemTestAuthentication

    setup do
      @admin = FactoryBot.create(:admin)
      @application = FactoryBot.create(:application, :old_enough_for_new_application, :with_medical_certification_requested)
      sign_in(@admin)
    end

    test 'admin can approve and upload medical certification' do
      visit admin_application_path(@application)

      # Verify the upload form is present
      assert_selector 'h3', text: 'Upload Medical Certification'

      # Select approve option and attach file
      find('input[value="approved"]').click
      attach_file('medical_certification', Rails.root.join('test/fixtures/files/medical_certification_valid.pdf'))

      # Submit the form
      click_button 'Process Certification'

      # Assert success message
      assert_text(/certification.*uploaded.*approved/i)

      # Verify the certification was attached
      assert @application.reload.medical_certification.attached?
      assert_equal 'approved', @application.medical_certification_status
    end

    test 'admin can reject medical certification with reason' do
      visit admin_application_path(@application)

      # Ensure upload form heading is present
      assert_selector 'h3', text: 'Upload Medical Certification'
      # Select reject option
      find('input[value="rejected"]').click

      # Wait for the rejection reason dropdown to appear after selecting "Reject Certification"
      find('select#medical_certification_rejection_reason', wait: 3).select('Missing Information')

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
      find('input[value="approved"]').click

      # Submit the form
      click_button 'Process Certification'

      # Assert error message
      assert_text(/file.*upload/i)
    end

    test 'admin must select a rejection reason when rejecting' do
      visit admin_application_path(@application)

      # Select reject option but intentionally skip selecting a reason to trigger validation
      find('input[value="rejected"]').click

      click_button 'Process Certification'

      # Expect an error related to missing rejection reason
      assert_text(/rejection reason is required|select.*rejection.*reason/i)
    end
  end
end
