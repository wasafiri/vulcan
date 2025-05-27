# frozen_string_literal: true

require 'test_helper'

module Applications
  class DependentEmailHandlingTest < ActiveSupport::TestCase
    setup do
      @admin = create(:admin)
      @guardian = create(:constituent, email: 'guardian@example.com')
    end

    test 'creates dependent using guardian email when use_guardian_address is checked' do
      # Create parameters for a paper application with use_guardian_address checked
      service = PaperApplicationService.new(
        params: {
          applicant_type: 'dependent',
          guardian_id: @guardian.id,
          use_guardian_address: '1', # This should trigger using guardian's email
          relationship_type: 'Parent',
          constituent: {
            first_name: 'Dependent',
            last_name: 'User',
            date_of_birth: '2015-01-01'
            # NOTE: email intentionally omitted to simulate when it's not filled in
            # since the checkbox for using guardian's email is checked
          },
          application: {
            household_size: 2,
            annual_income: 20_000,
            maryland_resident: true,
            medical_provider_name: 'Dr. Test',
            medical_provider_phone: '555-123-4567',
            medical_provider_email: 'doctor@example.com',
            self_certify_disability: true
          },
          applicant_attributes: {
            hearing_disability: '1'
          },
          income_proof_action: 'accept',
          residency_proof_action: 'accept'
        },
        admin: @admin
      )

      # Mock just enough for proof upload
      ProofAttachmentService.stubs(:attach_proof).returns({ success: true })
      ProofAttachmentService.stubs(:reject_proof_without_attachment).returns({ success: true })

      assert service.create, "Paper application creation failed: #{service.errors.join('; ')}"

      # Verify the dependent was created
      dependent = service.constituent
      assert_not_nil dependent, 'Dependent should have been created'

      # Key assertion: The dependent should have the guardian's email
      assert_equal @guardian.email, dependent.email,
                   "Dependent should have guardian's email when use_guardian_address is checked"
    end

    test 'creates dependent with their own email when provided' do # rubocop:disable Metrics/BlockLength
      dependent_email = "dependent_#{Time.now.to_i}@example.com"

      # Create parameters for a paper application with the dependent's own email
      service = PaperApplicationService.new(
        params: {
          applicant_type: 'dependent',
          guardian_id: @guardian.id,
          use_guardian_address: '0', # Not using guardian's address/email
          relationship_type: 'Parent',
          constituent: {
            first_name: 'Dependent',
            last_name: 'User',
            date_of_birth: '2015-01-01',
            email: dependent_email # Providing a distinct email for the dependent
          },
          application: {
            household_size: 2,
            annual_income: 20_000,
            maryland_resident: true,
            medical_provider_name: 'Dr. Test',
            medical_provider_phone: '555-123-4567',
            medical_provider_email: 'doctor@example.com',
            self_certify_disability: true
          },
          applicant_attributes: {
            hearing_disability: '1'
          },
          income_proof_action: 'accept',
          residency_proof_action: 'accept'
        },
        admin: @admin
      )

      # Mock proof uploads
      ProofAttachmentService.stubs(:attach_proof).returns({ success: true })
      ProofAttachmentService.stubs(:reject_proof_without_attachment).returns({ success: true })

      assert service.create, "Paper application creation failed: #{service.errors.join('; ')}"

      # Verify the dependent was created with their own email
      dependent = service.constituent
      assert_not_nil dependent, 'Dependent should have been created'
      assert_equal dependent_email, dependent.email,
                   'Dependent should keep their own email when provided'
    end
  end
end
