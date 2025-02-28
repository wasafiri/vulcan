FactoryBot.define do
  factory :application do
    # Required associations
    association :user, factory: [ :constituent, :with_disabilities ], strategy: :create

    # Base status fields with default values
    status { :in_progress }
    income_proof_status { :not_reviewed }  # Add default value
    residency_proof_status { :not_reviewed }  # Add default value

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

    after(:build) do |application|
      # Create and attach proofs
      fixture_dir = Rails.root.join("test", "fixtures", "files")
      FileUtils.mkdir_p(fixture_dir)
      [ "income_proof.pdf", "residency_proof.pdf" ].each do |filename|
        file_path = fixture_dir.join(filename)
        unless File.exist?(file_path)
          File.write(file_path, "test content for #{filename}")
        end
        proof_type = filename.sub(".pdf", "").to_sym
        application.public_send(proof_type).attach(
          io: File.open(file_path),
          filename: filename,
          content_type: "application/pdf"
        )
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
      association :income_verified_by, factory: :admin
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

      after(:build) do |application|
        fixture_dir = Rails.root.join("test", "fixtures", "files")
        FileUtils.mkdir_p(fixture_dir)
        [ "income_proof_rejected.pdf", "residency_proof_rejected.pdf" ].each do |filename|
          file_path = fixture_dir.join(filename)
          unless File.exist?(file_path)
            File.write(file_path, "test content for #{filename}")
          end
          proof_type = filename.sub("_rejected.pdf", "").to_sym
          application.public_send(proof_type).attach(
            io: File.open(file_path),
            filename: filename,
            content_type: "application/pdf"
          )
        end
      end
    end

    trait :with_approved_proofs do
      income_proof_status { :approved }
      residency_proof_status { :approved }
      after(:create) do |application|
        # Attach test files
      end
    end

  trait :in_progress_with_approved_proofs do
    household_size { 4 }
    annual_income  { 50_000 }
    status { :in_progress }
    income_proof_status { :approved }
    residency_proof_status { :approved }
    last_activity_at { Time.current }

    after(:build) do |application|
      fixture_dir = Rails.root.join("test", "fixtures", "files")
      FileUtils.mkdir_p(fixture_dir)
      files = {
        "approved_income_proof.pdf" => :income_proof,
        "placeholder_residency_proof.pdf" => :residency_proof
      }
      files.each do |filename, proof_type|
        file_path = fixture_dir.join(filename)
        unless File.exist?(file_path)
          File.write(file_path, "test content for #{filename}")
        end
        application.public_send(proof_type).attach(
          io: File.open(file_path),
          filename: filename,
          content_type: "application/pdf"
        )
      end
    end
  end

  trait :in_progress_with_pending_proofs do
    household_size { 4 }
    annual_income  { 50_000 }
    status { :in_progress }
    income_proof_status { :not_reviewed }
    residency_proof_status { :not_reviewed }
    last_activity_at { Time.current }

    after(:build) do |application|
      fixture_dir = Rails.root.join("test", "fixtures", "files")
      FileUtils.mkdir_p(fixture_dir)
      files = {
        "income_proof.pdf" => :income_proof,
        "residency_proof.pdf" => :residency_proof
      }
      files.each do |filename, proof_type|
        file_path = fixture_dir.join(filename)
        unless File.exist?(file_path)
          File.write(file_path, "test content for #{filename}")
        end
        application.public_send(proof_type).attach(
          io: File.open(file_path),
          filename: filename,
          content_type: "application/pdf"
        )
      end
    end
  end
  end
end
