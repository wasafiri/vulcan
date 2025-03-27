# frozen_string_literal: true

require 'test_helper'

module Applications
  class PaperApplicationAttachmentTest < ActiveSupport::TestCase
    setup do
      @admin = users(:admin)
      @income_proof = fixture_file_upload('test/fixtures/files/income_proof_sample.pdf', 'application/pdf')
      @residency_proof = fixture_file_upload('test/fixtures/files/residency_proof_sample.pdf', 'application/pdf')
    end

    test 'can attach proofs using ActiveStorage::Blob.find_signed' do
      income_blob, residency_blob = create_blobs
      params = direct_upload_params(income_blob.signed_id, residency_blob.signed_id)
      mock_policy

      service = PaperApplicationService.new(params: params, admin: @admin)
      assert service.create, "Paper application creation failed with errors: #{service.errors.join(', ')}"
      assert_attachments(service.application, income_blob, residency_blob)
    end

    test 'can attach proofs using GlobalID::Locator.locate_signed' do
      income_blob, residency_blob = create_blobs
      income_signed_gid = GlobalID::Locator.instance.signed_global_id_for(income_blob)
      residency_signed_gid = GlobalID::Locator.instance.signed_global_id_for(residency_blob)
      params = globalid_upload_params(income_signed_gid, residency_signed_gid)
      mock_policy

      service = PaperApplicationService.new(params: params, admin: @admin)
      assert service.create, "Paper application creation failed with errors: #{service.errors.join(', ')}"
      assert_attachments(service.application, income_blob, residency_blob)
    end

    private

    def create_blobs
      income_blob = ActiveStorage::Blob.create_and_upload!(
        io: @income_proof.open,
        filename: @income_proof.original_filename,
        content_type: @income_proof.content_type
      )
      residency_blob = ActiveStorage::Blob.create_and_upload!(
        io: @residency_proof.open,
        filename: @residency_proof.original_filename,
        content_type: @residency_proof.content_type
      )
      [income_blob, residency_blob]
    end

    def direct_upload_params(income_blob_signed_id, residency_blob_signed_id)
      {
        constituent: {
          first_name: 'Jane',
          last_name: 'Doe',
          email: 'jane.doe@example.com',
          phone: '301-555-1212',
          physical_address_1: '123 Main St',
          city: 'Baltimore',
          state: 'MD',
          zip_code: '21201',
          cognition_disability: '1'
        },
        application: {
          household_size: 1,
          annual_income: '18000',
          maryland_resident: true,
          self_certify_disability: true,
          medical_provider_name: 'Dr. Smith',
          medical_provider_phone: '301-555-1313'
        },
        income_proof_action: 'accept',
        income_proof: income_blob_signed_id,
        residency_proof_action: 'accept',
        residency_proof: residency_blob_signed_id
      }
    end

    def globalid_upload_params(income_signed_gid, residency_signed_gid)
      {
        constituent: {
          first_name: 'John',
          last_name: 'Smith',
          email: 'john.smith@example.com',
          phone: '301-555-1212',
          physical_address_1: '456 Oak St',
          city: 'Baltimore',
          state: 'MD',
          zip_code: '21201',
          cognition_disability: '1'
        },
        application: {
          household_size: 1,
          annual_income: '18000',
          maryland_resident: true,
          self_certify_disability: true,
          medical_provider_name: 'Dr. Jones',
          medical_provider_phone: '301-555-1313'
        },
        income_proof_action: 'accept',
        income_proof: income_signed_gid,
        residency_proof_action: 'accept',
        residency_proof: residency_signed_gid
      }
    end

    def assert_attachments(application, income_blob, residency_blob)
      assert application.present?, 'Application was not created'
      assert application.income_proof.attached?, 'Income proof was not attached'
      assert application.residency_proof.attached?, 'Residency proof was not attached'
      assert_equal income_blob.id, application.income_proof.blob.id, 'Income proof blob mismatch'
      assert_equal residency_blob.id, application.residency_proof.blob.id, 'Residency proof blob mismatch'
    end

    def mock_policy
      Policy.expects(:get).with(:fpl_1_person).returns('20000')
      Policy.expects(:get).with(:fpl_modifier_percentage).returns('200')
    end
  end
end
