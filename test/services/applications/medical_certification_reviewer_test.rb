# frozen_string_literal: true

require 'test_helper'

module Applications
  class MedicalCertificationReviewerTest < ActiveSupport::TestCase
    setup do
      @application = applications(:with_medical_provider)
      @admin = users(:admin)
      @service = MedicalCertificationReviewer.new(@application, @admin)
      
      # Make sure we have contact methods available
      @application.update(
        medical_provider_name: "Dr. Test Provider",
        medical_provider_email: "provider@example.com",
        medical_provider_fax: "555-123-4567"
      )
    end

    test "successfully rejects a medical certification" do
      # Set up a mock for the notifier
      notifier_mock = Minitest::Mock.new
      notifier_mock.expect :notify_certification_rejection, true, [{ rejection_reason: "Invalid documentation", admin: @admin }]
      
      # Replace the MedicalProviderNotifier with our mock
      MedicalProviderNotifier.stub :new, notifier_mock do
        result = @service.reject(rejection_reason: "Invalid documentation")
        assert result[:success], "Expected rejection to succeed"
      end
      
      # Verify the mock was called as expected
      assert_mock notifier_mock
      
      # Verify application status was updated
      assert_equal "rejected", @application.reload.medical_certification_status
    end

    test "fails when rejection reason is missing" do
      result = @service.reject(rejection_reason: "")
      refute result[:success], "Expected rejection to fail without a reason"
      assert_match /Rejection reason is required/, result[:error]
    end

    test "fails when medical provider has no contact methods" do
      @application.update(medical_provider_email: nil, medical_provider_fax: nil)
      
      result = @service.reject(rejection_reason: "Invalid documentation")
      refute result[:success], "Expected rejection to fail without contact methods"
      assert_match /No contact method available/, result[:error]
    end

    test "creates an application note when notes are provided" do
      # Mock the notifier to return success
      MedicalProviderNotifier.stub_any_instance(:notify_certification_rejection, true) do
        assert_difference -> { @application.application_notes.count }, 1 do
          @service.reject(rejection_reason: "Invalid documentation", notes: "Follow up required")
        end
      end
      
      note = @application.application_notes.last
      assert_equal "medical_certification", note.note_type
      assert_match /Follow up required/, note.content
    end

    test "creates application status change record" do
      # Mock the notifier to return success
      MedicalProviderNotifier.stub_any_instance(:notify_certification_rejection, true) do
        assert_difference -> { ApplicationStatusChange.count }, 1 do
          @service.reject(rejection_reason: "Invalid documentation")
        end
      end
      
      status_change = ApplicationStatusChange.last
      assert_equal @application.id, status_change.application_id
      assert_equal @admin.id, status_change.user_id
      assert_equal "rejected", status_change.to_status
      assert_equal "medical_certification", status_change.change_type
      assert_equal "Invalid documentation", status_change.metadata["rejection_reason"]
    end

    test "proceeds even when notification fails" do
      # Mock the notifier to return failure
      MedicalProviderNotifier.stub_any_instance(:notify_certification_rejection, false) do
        result = @service.reject(rejection_reason: "Invalid documentation")
        assert result[:success], "Expected overall rejection to succeed even when notification fails"
      end
      
      # Verify application status was still updated
      assert_equal "rejected", @application.reload.medical_certification_status
    end

    test "returns error when application update fails" do
      # Force the application update to fail
      @application.stub :update_certification!, -> (*args) { raise ActiveRecord::RecordInvalid.new(@application) } do
        result = @service.reject(rejection_reason: "Invalid documentation")
        refute result[:success], "Expected rejection to fail when app update fails"
        assert_match /Failed to update application/, result[:error]
      end
    end
  end
end
