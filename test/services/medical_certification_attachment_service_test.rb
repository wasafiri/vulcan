# frozen_string_literal: true

require 'test_helper'

class MedicalCertificationAttachmentServiceTest < ActiveSupport::TestCase
  include ActiveStorageHelper

  setup do
    @application = applications(:pending_application)
    @admin = users(:admin_user)
    @test_file = fixture_file_upload('files/test_medical_certification.pdf', 'application/pdf')
    clear_active_storage
  end

  test 'attaches medical certification with ActionDispatch::Http::UploadedFile' do
    # Test the specific fix we made for direct file uploads
    assert_difference 'ActiveStorage::Attachment.count' do
      result = MedicalCertificationAttachmentService.attach_certification(
        application: @application,
        blob_or_file: @test_file,
        status: :accepted,
        admin: @admin,
        submission_method: :admin_upload
      )

      assert result[:success], 'Direct file upload should succeed'
      assert @application.reload.medical_certification.attached?
      assert_equal 'accepted', @application.medical_certification_status
    end
  end
  
  test 'handles failed blob creation gracefully with fallback' do
    # Mock Blob.create_and_upload! to simulate a failure
    ActiveStorage::Blob.stub :create_and_upload!, ->(_args) { raise StandardError, 'Simulated blob creation failure' } do
      # Should still succeed because our fix explicitly sets attachment_param = blob_or_file before trying blob creation
      assert_difference 'ActiveStorage::Attachment.count' do
        result = MedicalCertificationAttachmentService.attach_certification(
          application: @application,
          blob_or_file: @test_file,
          status: :accepted,
          admin: @admin,
          submission_method: :admin_upload
        )
        
        assert result[:success], "Should succeed with fallback"
        assert @application.reload.medical_certification.attached?
      end
    end
  end
  
  test 'properly handles signed_id strings' do
    # First create a blob to get its signed_id
    blob = create_dummy_blob
    signed_id = blob.signed_id
    
    # Then use the signed_id for attachment
    assert_difference 'ActiveStorage::Attachment.count' do
      result = MedicalCertificationAttachmentService.attach_certification(
        application: @application,
        blob_or_file: signed_id,
        status: :accepted,
        admin: @admin,
        submission_method: :admin_upload
      )
      
      assert result[:success], "Signed ID should work correctly"
      assert @application.reload.medical_certification.attached?
    end
  end
  
  test 'rejects medical certification without requiring an attachment' do
    assert_no_difference 'ActiveStorage::Attachment.count' do
      result = MedicalCertificationAttachmentService.reject_certification(
        application: @application,
        admin: @admin,
        reason: 'missing_signature',
        notes: 'Test rejection note',
        submission_method: :admin_review
      )
      
      assert result[:success], "Rejection should succeed"
      assert_equal 'rejected', @application.reload.medical_certification_status
      assert_equal 'missing_signature', @application.medical_certification_rejection_reason
    end
  end
  
  private
  
  def create_dummy_blob
    ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new("dummy content"),
      filename: "dummy.txt",
      content_type: "text/plain"
    )
  end
end
