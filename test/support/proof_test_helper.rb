# frozen_string_literal: true

# Helper module for managing proofs in tests
module ProofTestHelper
  # Setup an application for testing by ensuring it has the correct proof status and attachments
  #
  # @param app [Application] The application to prepare for testing
  # @param options [Hash] Configuration options
  # @option options [Boolean] :stub_attachments (true) Whether to stub attachment methods
  # @option options [String] :status ('in_progress') The application status
  # @option options [String] :income_proof_status ('not_reviewed') The income proof status
  # @option options [String] :residency_proof_status ('not_reviewed') The residency proof status
  # @option options [Boolean] :stub_medical_certification (false) Whether to stub medical certification
  # @return [Application] The prepared application
  #
  # @deprecated Consider using factories with traits instead:
  #   create(:application, :with_mocked_income_proof, :with_mocked_residency_proof, status: 'in_progress')
  #   For real attachments: create(:application, :with_real_income_proof, :with_real_residency_proof)
  def prepare_application_for_test(app, options = {})
    # Default options
    options = {
      stub_attachments: true,
      status: 'in_progress',
      income_proof_status: 'not_reviewed',
      residency_proof_status: 'not_reviewed',
      stub_medical_certification: false
    }.merge(options)

    # Update application status fields
    app.update!(
      status: options[:status],
      income_proof_status: options[:income_proof_status],
      residency_proof_status: options[:residency_proof_status]
    )

    # Setup attachment mocks if requested
    if options[:stub_attachments]
      # Use AttachmentTestHelper#mock_attached_file to create standardized mocks
      income_proof_mock = mock_attached_file(filename: 'income_proof.pdf')
      residency_proof_mock = mock_attached_file(filename: 'residency_proof.pdf')

      app.stubs(:income_proof_attached?).returns(true)
      app.stubs(:income_proof).returns(income_proof_mock)

      app.stubs(:residency_proof_attached?).returns(true)
      app.stubs(:residency_proof).returns(residency_proof_mock)

      # Setup medical certification mock if requested
      if options[:stub_medical_certification]
        med_cert_mock = mock_attached_file(filename: 'medical_certification.pdf')
        app.stubs(:medical_certification_attached?).returns(true)
        app.stubs(:medical_certification).returns(med_cert_mock)
      end
    end

    app
  end

  # Setup attachment mocks for audit logs
  # This prevents common errors like "uninitialized method byte_size" during tests
  #
  # @deprecated Consider using :with_mocked_income_proof and :with_mocked_residency_proof
  #   factory traits instead of this helper
  def setup_attachment_mocks_for_audit_logs
    # Find all applications in fixtures and mock their attachments
    # This prevents errors in tests that iterate through applications
    Application.all.each do |app|
      # Use AttachmentTestHelper#mock_attached_file to create standardized mocks
      income_proof_mock = mock_attached_file(filename: 'income_proof.pdf')
      residency_proof_mock = mock_attached_file(filename: 'residency_proof.pdf')

      app.stubs(:income_proof_attached?).returns(true)
      app.stubs(:income_proof).returns(income_proof_mock)

      app.stubs(:residency_proof_attached?).returns(true)
      app.stubs(:residency_proof).returns(residency_proof_mock)
    end
  end

  # Create a test application with standardized factory traits for proofs
  #
  # @param options [Hash] Configuration options
  # @option options [Symbol] :attachment_type (:mock) Use :mock or :real attachments
  # @option options [String] :status ('in_progress') The application status
  # @option options [String] :income_proof_status ('not_reviewed') The income proof status
  # @option options [String] :residency_proof_status ('not_reviewed') The residency proof status
  # @option options [Boolean] :with_medical_certification (false) Whether to include medical certification
  # @return [Application] The created application
  def create_application_with_proofs(options = {})
    # Default options
    options = {
      attachment_type: :mock,
      status: 'in_progress',
      income_proof_status: 'not_reviewed',
      residency_proof_status: 'not_reviewed',
      with_medical_certification: false
    }.merge(options)

    # Set up traits based on options
    traits = []

    if options[:attachment_type] == :mock
      traits << :with_mocked_income_proof
      traits << :with_mocked_residency_proof
      traits << :with_mocked_medical_certification if options[:with_medical_certification]
    else
      traits << :with_real_income_proof
      traits << :with_real_residency_proof
      traits << :with_real_medical_certification if options[:with_medical_certification]
    end

    # Create application with desired traits and attributes
    FactoryBot.create(:application, *traits,
      status: options[:status],
      income_proof_status: options[:income_proof_status],
      residency_proof_status: options[:residency_proof_status]
    )
  end
end
