# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class MedicalCertificationUploadTest < ApplicationSystemTestCase
    setup do
      @admin = create(:admin)
      @application = create(:application, :in_progress)
      @application.update(medical_certification_status: 'requested')

      # Sign in as admin
      visit new_user_session_path
      fill_in 'Email', with: @admin.email
      fill_in 'Password', with: 'password'
      click_button 'Sign In'
    end

    test 'admin can approve a medical certification during upload' do
      visit admin_application_path(@application)

      # Verify the upload form is displayed
      assert_selector '[data-testid="medical-certification-upload-form"]'

      # Select the "Approve" option
      choose 'Accept Certification and Upload'

      # Attach a test file to the upload form
      file_path = Rails.root.join('test/fixtures/files/test_document.pdf')
      attach_file 'medical_certification', file_path, make_visible: true

      # Submit the form
      click_button 'Process Certification'

      # Verify success message is displayed
      assert_text 'Medical certification successfully uploaded and approved'

      # Verify the certification status changed to 'approved'
      @application.reload
      assert_equal 'approved', @application.medical_certification_status

      # Verify the document is attached
      assert @application.medical_certification.attached?

      # Verify that audit trail entry was created
      assert ApplicationStatusChange.where(
        application: @application,
        change_type: 'medical_certification',
        from_status: 'requested',
        to_status: 'approved'
      ).exists?
    end

    test 'admin can reject a medical certification without uploading' do
      visit admin_application_path(@application)

      # Select the "Reject" option
      choose 'Reject Certification'

      # Wait for rejection section to become visible
      assert_selector 'select[name="rejection_reason"]', visible: true

      # Select a rejection reason and add notes
      select 'Incomplete Form', from: 'rejection_reason'
      fill_in 'notes', with: 'The certification form is missing required signatures'

      # Submit the form
      click_button 'Process Certification'

      # Verify success message is displayed
      assert_text 'Medical certification rejected and provider notified'

      # Verify the certification status changed to 'rejected'
      @application.reload
      assert_equal 'rejected', @application.medical_certification_status

      # Verify that audit trail entry was created
      assert ApplicationStatusChange.where(
        application: @application,
        change_type: 'medical_certification',
        from_status: 'requested',
        to_status: 'rejected'
      ).exists?
    end

    test 'admin sees error when trying to approve without a file' do
      visit admin_application_path(@application)

      # Select the "Approve" option
      choose 'Accept Certification and Upload'

      # Try to submit without attaching a file
      click_button 'Process Certification'

      # Verify error message is displayed
      assert_text 'Please select a file to upload'

      # Verify status remained 'requested'
      @application.reload
      assert_equal 'requested', @application.medical_certification_status
    end

    test 'admin sees error when trying to reject without a reason' do
      visit admin_application_path(@application)

      # Select the "Reject" option
      choose 'Reject Certification'

      # Try to submit without selecting a rejection reason
      click_button 'Process Certification'

      # Verify error message is displayed
      assert_text 'Please select a rejection reason'

      # Verify status remained 'requested'
      @application.reload
      assert_equal 'requested', @application.medical_certification_status
    end

    test 'upload form is not shown when medical certification is already attached' do
      # Prepare an application that already has a certification attached
      @application.medical_certification.attach(
        io: StringIO.new('test content'),
        filename: 'already_attached.pdf',
        content_type: 'application/pdf'
      )
      @application.update(medical_certification_status: 'received')

      visit admin_application_path(@application)

      # Verify upload form is not shown
      assert_no_selector '[data-testid="medical-certification-upload-form"]'

      # But the link to view the certification is shown
      assert_text 'View Medical Certification Document'
    end
  end
end
