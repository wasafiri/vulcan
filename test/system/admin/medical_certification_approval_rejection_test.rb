# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  # Tests the functionality of the combined medical certification upload/review process,
  # specifically the ability to approve or reject a certification at the time of upload
  class MedicalCertificationApprovalRejectionTest < ApplicationSystemTestCase
    include SystemTestAuthentication

    setup do
      # Create admin user
      @admin = users(:admin)
      system_test_sign_in(@admin)

      # Create an application with a requested medical certification
      @application = Application.where(medical_certification_status: 'requested').first
      @application ||= Application.create!(
        user: users(:constituent_john),
        status: 'in_progress',
        application_date: Date.current,
        maryland_resident: true,
        self_certify_disability: true,
        medical_provider_name: 'Dr. Test',
        medical_certification_status: 'requested',
        household_size: 2,
        annual_income: 30000
      )
    end

    test 'can upload and approve a medical certification' do
      visit admin_application_path(@application)

      # Verify upload form is visible
      assert_selector 'h3', text: 'Upload Medical Certification'

      # Select approve option
      find('input[type="radio"][value="approved"]').click

      # Attach a file
      attach_file('medical_certification', Rails.root.join('test/fixtures/files/medical_certification_valid.pdf'), visible: false)

      # Submit the form
      click_on 'Process Certification'

      # Verify success
      assert_text 'Medical certification successfully uploaded and approved'
      assert @application.reload.medical_certification.attached?
      assert_equal 'approved', @application.medical_certification_status
    end

    test 'can reject a medical certification with a reason' do
      skip 'Skipping until medical certification rejection UI refactor is completed'
      
      visit admin_application_path(@application)

      # Verify upload form is visible
      assert_selector 'h3', text: 'Upload Medical Certification'

      # Select reject option
      find('input[type="radio"][value="rejected"]').click

      # Wait for the rejection section to appear
      assert_selector '[data-medical-certification-target="rejectionSection"]', visible: true

      # Click a predefined reason button
      find('button[data-reason-type="missing-signature"]').click

      # The reason field should be populated
      reason_field = find('[data-medical-certification-target="reasonField"]')
      assert reason_field.value.present?

      # Add some notes
      fill_in 'medical_certification_rejection_notes', with: 'Please have the doctor sign the form and resubmit'

      # Submit the form
      click_on 'Process Certification'

      # Verify success
      assert_text 'Medical certification rejected and provider notified'
      assert_equal 'rejected', @application.reload.medical_certification_status
    end

    test 'validates that rejection reason is provided' do
      skip 'Skipping until medical certification rejection UI refactor is completed'
      
      visit admin_application_path(@application)

      # Select reject option
      find('input[type="radio"][value="rejected"]').click

      # Submit form without providing a reason
      click_on 'Process Certification'

      # Should show validation error
      assert_selector '.text-red-600', text: 'Please provide a rejection reason'

      # Status should not change
      assert_equal 'requested', @application.reload.medical_certification_status
    end

    test 'debug data attributes for predefined rejection reasons' do
      skip 'Skipping until medical certification rejection UI refactor is completed'
      
      visit admin_application_path(@application)

      # Select reject option to show rejection section
      find('input[type="radio"][value="rejected"]').click

      # List all predefined reason buttons
      buttons = all('button[data-reason-type]')

      # Output for debugging
      puts "Found #{buttons.count} predefined reason buttons:"
      buttons.each do |button|
        reason_type = button['data-reason-type']
        puts "Button with data-reason-type='#{reason_type}'"
      end

      # Check if form container has the expected data attributes
      form_container = find('[data-controller~="medical-certification"]')
      puts 'Form container data attributes:'
      form_container['data'].to_s.split.each do |attr|
        puts "  #{attr}" if attr.start_with?('data-')
      end
    end
  end
end
