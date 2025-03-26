# frozen_string_literal: true

# Helper module for managing proofs in tests
module ProofTestHelper
  # Setup an application for testing by ensuring it has the correct proof status and attachments
  def prepare_application_for_test(app, options = {})
    # Default options
    options = {
      stub_attachments: true,
      status: 'in_progress',
      income_proof_status: 'not_reviewed',
      residency_proof_status: 'not_reviewed'
    }.merge(options)

    # Enable paper application context to bypass certain validations
    Thread.current[:paper_application_context] = true
    Thread.current[:skip_proof_validation] = true

    # Stub attachments if needed - this avoids the need for actual files
    if options[:stub_attachments]
      # Create blob mocks that allow any method calls
      income_blob = mock
      income_blob.stubs(:content_type).with(any_parameters).returns('application/pdf')
      income_blob.stubs(:byte_size).with(any_parameters).returns(1024)
      income_blob.stubs(:created_at).with(any_parameters).returns(1.day.ago)
      income_blob.stubs(:filename).with(any_parameters).returns('income.pdf')
      
      residency_blob = mock
      residency_blob.stubs(:content_type).with(any_parameters).returns('application/pdf')
      residency_blob.stubs(:byte_size).with(any_parameters).returns(1024)
      residency_blob.stubs(:created_at).with(any_parameters).returns(1.day.ago)
      residency_blob.stubs(:filename).with(any_parameters).returns('residency.pdf')
      
      # Create attachment mocks with flexible method calls
      income_proof_mock = mock
      income_proof_mock.stubs(:attached?).with(any_parameters).returns(true)
      income_proof_mock.stubs(:blob).with(any_parameters).returns(income_blob)
      income_proof_mock.stubs(:content_type).with(any_parameters).returns('application/pdf')
      income_proof_mock.stubs(:download).with(any_parameters).returns("fake pdf content")
      income_proof_mock.stubs(:filename).with(any_parameters).returns('income.pdf')
      
      residency_proof_mock = mock
      residency_proof_mock.stubs(:attached?).with(any_parameters).returns(true)
      residency_proof_mock.stubs(:blob).with(any_parameters).returns(residency_blob)
      residency_proof_mock.stubs(:content_type).with(any_parameters).returns('application/pdf')
      residency_proof_mock.stubs(:download).with(any_parameters).returns("fake pdf content")
      residency_proof_mock.stubs(:filename).with(any_parameters).returns('residency.pdf')
      
      # Stub methods at the Application level
      Application.any_instance.stubs(:income_proof_attached?).with(any_parameters).returns(true)
      Application.any_instance.stubs(:residency_proof_attached?).with(any_parameters).returns(true)
      Application.any_instance.stubs(:income_proof).with(any_parameters).returns(income_proof_mock)
      Application.any_instance.stubs(:residency_proof).with(any_parameters).returns(residency_proof_mock)
    end

    # Update the application with the specified options
    app.update!(
      status: options[:status],
      income_proof_status: options[:income_proof_status],
      residency_proof_status: options[:residency_proof_status]
    )

    # Clean up the thread locals
    Thread.current[:paper_application_context] = false

    # Return the prepared application
    app
  end
end
