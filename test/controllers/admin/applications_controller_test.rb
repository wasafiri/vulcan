# frozen_string_literal: true

require 'test_helper'

module Admin
  class ApplicationsControllerTest < ActionDispatch::IntegrationTest

    setup do
      @admin = users(:admin)
      sign_in @admin
      @application = applications(:active)
      @application.update(medical_certification_status: 'requested')
    end

    test 'should get index' do
      get admin_applications_path
      assert_response :success
    end

    test 'should show application' do
      get admin_application_path(@application)
      assert_response :success
    end

    test 'should upload medical certification document' do
      assert_equal 'requested', @application.medical_certification_status
      assert_not @application.medical_certification.attached?

      # Create a test file for upload
      file = fixture_file_upload(
        Rails.root.join('test', 'fixtures', 'files', 'test_document.pdf'),
        'application/pdf'
      )

      # Submit the upload form with approval status
      patch upload_medical_certification_admin_application_path(@application),
            params: { medical_certification: file, medical_certification_status: 'approved' }

      # Verify the results
      assert_redirected_to admin_application_path(@application)
      follow_redirect!
      assert_response :success
      assert_match(/Medical certification successfully uploaded and approved/, flash[:notice])

      # Reload the application and check the status and attachment
      @application.reload
      assert_equal 'approved', @application.medical_certification_status
      assert @application.medical_certification.attached?

      # Verify an audit entry was created
      assert ApplicationStatusChange.where(
        application: @application,
        user: @admin,
        from_status: 'requested',
        to_status: 'approved',
        change_type: 'medical_certification'
      ).exists?
    end
    
    test 'should reject upload without file' do
      patch upload_medical_certification_admin_application_path(@application),
            params: { medical_certification: nil, medical_certification_status: 'approved' }
            
      assert_redirected_to admin_application_path(@application)
      follow_redirect!
      assert_response :success
      assert_match(/Please select a file to upload/, flash[:alert])
      
      # Ensure status hasn't changed
      @application.reload
      assert_equal 'requested', @application.medical_certification_status

      # Test rejection without status selection
      file = fixture_file_upload(
        Rails.root.join('test', 'fixtures', 'files', 'test_document.pdf'),
        'application/pdf'
      )
      patch upload_medical_certification_admin_application_path(@application),
            params: { medical_certification: file }

      assert_redirected_to admin_application_path(@application)
      follow_redirect!
      assert_response :success
      assert_match(/Please select whether to accept or reject the certification/, flash[:alert])

      # Ensure status still hasn't changed
      @application.reload
      assert_equal 'requested', @application.medical_certification_status
      assert_not @application.medical_certification.attached?
    end
  end
end
