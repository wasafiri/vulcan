# frozen_string_literal: true

FactoryBot.define do
  factory :application do
    # Required associations
    user factory: %i[constituent with_disabilities], strategy: :create

    # Make managing_guardian truly optional by not specifying it by default
    # It will be nil unless explicitly set in the test

    # Base status fields with default values
    status { :in_progress }
    income_proof_status { :not_reviewed } # Add default value
    residency_proof_status { :not_reviewed } # Add default value
    medical_certification_status { :not_requested } # Valid enum value

    # Other required fields
    application_date { Time.current }
    maryland_resident { true }
    self_certify_disability { true }
    medical_provider_name { generate(:medical_provider_name) }
    medical_provider_phone { generate(:medical_provider_phone) }
    medical_provider_fax { generate(:medical_provider_fax) }
    medical_provider_email { generate(:medical_provider_email) }
    household_size { 4 }
    annual_income  { 50_000 }

    transient do
      skip_proofs { false }
      use_mock_attachments { false } # Whether to use mock_attached_file instead of real attachments
    end

    # Attachment traits that use the standardized mock_attached_file approach
    trait :with_mocked_income_proof do
      after(:build) do |application|
        income_proof_mock = mock_attached_file(filename: 'income.pdf')
        application.stubs(:income_proof_attached?).returns(true)
        application.stubs(:income_proof).returns(income_proof_mock)
      end
    end

    trait :with_mocked_residency_proof do
      after(:build) do |application|
        residency_proof_mock = mock_attached_file(filename: 'residency.pdf')
        application.stubs(:residency_proof_attached?).returns(true)
        application.stubs(:residency_proof).returns(residency_proof_mock)
      end
    end

    trait :with_mocked_medical_certification do
      after(:build) do |application|
        medical_certification_mock = mock_attached_file(filename: 'medical_certification.pdf')
        application.stubs(:medical_certification_attached?).returns(true)
        application.stubs(:medical_certification).returns(medical_certification_mock)
      end
    end

    trait :with_all_mocked_attachments do
      with_mocked_income_proof
      with_mocked_residency_proof
      with_mocked_medical_certification
    end

    # Real attachment traits that use actual file attachments (not mocks)
    # These are more suitable for integration/system tests where actual file processing is needed
    trait :with_real_income_proof do
      after(:build) do |application|
        # Use the module method from ActiveStorageTestHelper
        if ActiveStorageTestHelper.instance_methods.include?(:attach_income_proof)
          ActiveStorageTestHelper.new.attach_income_proof(application)
        else
          application.income_proof.attach(
            io: StringIO.new('income proof content'),
            filename: 'income.pdf',
            content_type: 'application/pdf'
          )
        end
      end
    end

    trait :with_real_residency_proof do
      after(:build) do |application|
        # Use the module method from ActiveStorageTestHelper
        if ActiveStorageTestHelper.instance_methods.include?(:attach_residency_proof)
          ActiveStorageTestHelper.new.attach_residency_proof(application)
        else
          application.residency_proof.attach(
            io: StringIO.new('residency proof content'),
            filename: 'residency.pdf',
            content_type: 'application/pdf'
          )
        end
      end
    end

    trait :with_real_medical_certification do
      after(:build) do |application|
        # Use the module method from ActiveStorageTestHelper
        if ActiveStorageTestHelper.instance_methods.include?(:attach_medical_certification)
          ActiveStorageTestHelper.new.attach_medical_certification(application)
        else
          application.medical_certification.attach(
            io: StringIO.new('medical certification content'),
            filename: 'medical_certification.pdf',
            content_type: 'application/pdf'
          )
        end
      end
    end

    trait :with_all_real_attachments do
      with_real_income_proof
      with_real_residency_proof
      with_real_medical_certification
    end

    after(:build) do |application, evaluator|
      # Skip attachment during tests unless explicitly requested
      next if evaluator.skip_proofs

      # Set the thread variable to disable callbacks during factory creation
      original_context = Thread.current[:paper_application_context]
      Thread.current[:paper_application_context] = true

      # Attach known good PDF files using direct SQL to bypass callbacks
      begin
        # Create the blobs directly
        income_blob = ActiveStorage::Blob.create_and_upload!(
          io: Rails.root.join('test/fixtures/files/income_proof.pdf').open,
          filename: 'income_proof.pdf',
          content_type: 'application/pdf'
        )

        # Ensure the blob has a created_at timestamp
        income_blob.update_column(:created_at, 2.minutes.ago) if income_blob.created_at.nil?

        residency_blob = ActiveStorage::Blob.create_and_upload!(
          io: Rails.root.join('test/fixtures/files/residency_proof.pdf').open,
          filename: 'residency_proof.pdf',
          content_type: 'application/pdf'
        )

        # Ensure the blob has a created_at timestamp
        residency_blob.update_column(:created_at, 2.minutes.ago) if residency_blob.created_at.nil?

        # Create attachment records directly without callbacks
        if application.persisted?
          # Create attachments via direct SQL if the application is already persisted
          ActiveStorage::Attachment.insert_all([
                                                 {
                                                   name: 'income_proof',
                                                   record_type: 'Application',
                                                   record_id: application.id,
                                                   blob_id: income_blob.id,
                                                   created_at: Time.current
                                                 },
                                                 {
                                                   name: 'residency_proof',
                                                   record_type: 'Application',
                                                   record_id: application.id,
                                                   blob_id: residency_blob.id,
                                                   created_at: Time.current
                                                 }
                                               ])
        else
          # Use regular attach for non-persisted applications
          application.income_proof.attach(income_blob)
          application.residency_proof.attach(residency_blob)
        end
      ensure
        # Restore the thread variable
        Thread.current[:paper_application_context] = original_context
      end
    end

    trait :completed do
      household_size { 4 }
      annual_income  { 50_000 }
      status { :approved }
      income_proof_status { :approved }
      residency_proof_status { :approved }
      terms_accepted { true }
      information_verified { true }
      medical_release_authorized { true }
      income_verified_at { Time.current }
      last_activity_at { Time.current }
      income_verified_by factory: %i[admin]
    end

    trait :rejected do
      household_size { 2 }
      annual_income  { 300_000 }
      status { :rejected }
      income_proof_status { :rejected }
      residency_proof_status { :rejected }
      terms_accepted { true }
      information_verified { true }
      medical_release_authorized { true }
      total_rejections { 1 }
      needs_review_since { Time.current }
      last_activity_at { Time.current }
    end

    trait :archived do
      household_size { 4 }
      annual_income  { 50_000 }
      status { :archived }
      income_proof_status { :approved }
      residency_proof_status { :approved }
      terms_accepted { true }
      information_verified { true }
      medical_release_authorized { true }
      application_date { 8.years.ago }
      last_activity_at { 8.years.ago }
    end

    trait :in_progress_with_rejected_proofs do
      household_size { 4 }
      annual_income  { 50_000 }
      status { :in_progress }
      income_proof_status { :rejected }
      residency_proof_status { :rejected }
      needs_review_since { Time.current }
      last_activity_at { Time.current }

      # Use the same PDF files as the base factory - the status is what matters
      # No need to override attachment behavior
    end

    trait :with_approved_proofs do
      income_proof_status { :approved }
      residency_proof_status { :approved }
      # Use the same PDF files as the base factory
    end

    trait :in_progress_with_approved_proofs do
      household_size { 4 }
      annual_income  { 50_000 }
      status { :in_progress }
      income_proof_status { :approved }
      residency_proof_status { :approved }
      last_activity_at { Time.current }
      # Use the same PDF files as the base factory
    end

    trait :in_progress_with_pending_proofs do
      household_size { 4 }
      annual_income  { 50_000 }
      status { :in_progress }
      income_proof_status { :not_reviewed }
      residency_proof_status { :not_reviewed }
      last_activity_at { Time.current }
      # Use the same PDF files as the base factory
    end

    # This trait creates an application for a dependent, managed by a guardian.
    trait :for_dependent do
      transient do
        guardian { create(:constituent, first_name: 'Guardian', last_name: 'User') }
        dependent_attrs { { first_name: 'Dependent', last_name: 'User' } } # Pass attributes for the dependent
        relationship_type { 'Parent' }
      end

      # The main `user` of the application is the dependent.
      user factory: %i[constituent] # This will be overridden by the dependent created below

      after(:build) do |application, evaluator|
        # Ensure dependent is created using transient attributes
        dependent_user = create(:constituent, evaluator.dependent_attrs)
        application.user = dependent_user # Explicitly set the application's user to the dependent
        application.managing_guardian = evaluator.guardian

        # Create the relationship if it doesn't exist
        unless GuardianRelationship.exists?(guardian_user: evaluator.guardian, dependent_user: dependent_user)
          create(:guardian_relationship, guardian_user: evaluator.guardian, dependent_user: dependent_user,
                                         relationship_type: evaluator.relationship_type)
        end
      end
    end

    # DEPRECATED: Use :for_dependent trait for more clarity.
    trait :submitted_by_guardian do
      for_dependent # Delegates to the new :for_dependent trait
    end

    # DEPRECATED: Use :for_dependent trait with relationship_type: 'Legal Guardian'.
    trait :submitted_by_legal_guardian do
      for_dependent { { relationship_type: 'Legal Guardian' } } # Delegates with specific relationship
    end
  end
end
