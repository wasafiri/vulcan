FactoryBot.define do
  factory :proof_review do
    association :application, factory: :application
    association :admin
    proof_type { :income }  # or :residency
    status { :approved }
    reviewed_at { Time.current }

    # Ensure the application has the appropriate proof attached
    after(:build) do |proof_review|
      # Skip if we're using a custom application that already has proofs
      next if proof_review.application.income_proof.attached? && proof_review.application.residency_proof.attached?

      # Attach the appropriate proof based on the proof type
      fixture_dir = Rails.root.join("test", "fixtures", "files")
      FileUtils.mkdir_p(fixture_dir)

      # Determine which proof file to use
      proof_filename = case proof_review.proof_type
      when "income" then "test_income_proof.pdf"
      when "residency" then "test_residency_proof.pdf"
      else "test_proof.pdf"
      end

      # Create the file if it doesn't exist
      file_path = fixture_dir.join(proof_filename)
      unless File.exist?(file_path)
        File.write(file_path, "test content for #{proof_filename}")
      end

      # Attach the proof to the application
      proof_type = proof_review.proof_type.to_sym
      proof_review.application.public_send(:"#{proof_type}_proof").attach(
        io: File.open(file_path),
        filename: proof_filename,
        content_type: "application/pdf"
      )
    end

    trait :approved do
      status { :approved }
    end

    trait :rejected do
      status { :rejected }
      rejection_reason { "Invalid documentation" }
    end

    trait :with_income_proof do
      proof_type { :income }
      after(:build) do |proof_review|
        next if proof_review.application.income_proof.attached?

        fixture_dir = Rails.root.join("test", "fixtures", "files")
        file_path = fixture_dir.join("test_income_proof.pdf")
        unless File.exist?(file_path)
          File.write(file_path, "test content for income proof")
        end

        proof_review.application.income_proof.attach(
          io: File.open(file_path),
          filename: "test_income_proof.pdf",
          content_type: "application/pdf"
        )
      end
    end

    trait :with_residency_proof do
      proof_type { :residency }
      after(:build) do |proof_review|
        next if proof_review.application.residency_proof.attached?

        fixture_dir = Rails.root.join("test", "fixtures", "files")
        file_path = fixture_dir.join("test_residency_proof.pdf")
        unless File.exist?(file_path)
          File.write(file_path, "test content for residency proof")
        end

        proof_review.application.residency_proof.attach(
          io: File.open(file_path),
          filename: "test_residency_proof.pdf",
          content_type: "application/pdf"
        )
      end
    end
  end
end
