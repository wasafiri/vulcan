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
      
      # Set the thread variable to disable callbacks during factory creation
      original_context = Thread.current[:paper_application_context]
      Thread.current[:paper_application_context] = true

      begin
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

        # Create a blob directly and then create the attachment record directly
        blob = ActiveStorage::Blob.create_and_upload!(
          io: File.open(file_path),
          filename: proof_filename,
          content_type: "application/pdf"
        )
        
        # Update the blob's created_at timestamp directly
        blob.update_column(:created_at, 2.minutes.ago)
        
        # Determine the proof type attribute name
        proof_type = proof_review.proof_type.to_sym
        
        # If the application is persisted, use direct SQL
        if proof_review.application.persisted?
          ActiveStorage::Attachment.create(
            name: "#{proof_type}_proof",
            record_type: "Application",
            record_id: proof_review.application.id,
            blob_id: blob.id
          )
          
          # Update the application's proof status to match the review status
          proof_review.application.update_column(
            "#{proof_type}_proof_status", 
            Application.public_send("#{proof_type}_proof_statuses")[proof_review.status.to_s]
          )
        else
          # If not persisted, use regular attach (for build or create)
          proof_review.application.public_send(:"#{proof_type}_proof").attach(blob)
        end
      ensure
        # Restore the thread variable
        Thread.current[:paper_application_context] = original_context
      end
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
        
        # Set the thread variable to disable callbacks during factory creation
        original_context = Thread.current[:paper_application_context]
        Thread.current[:paper_application_context] = true
        
        begin
          fixture_dir = Rails.root.join("test", "fixtures", "files")
          file_path = fixture_dir.join("test_income_proof.pdf")
          unless File.exist?(file_path)
            File.write(file_path, "test content for income proof")
          end
          
          # Create a blob directly and then create the attachment record directly
          blob = ActiveStorage::Blob.create_and_upload!(
            io: File.open(file_path),
            filename: "test_income_proof.pdf",
            content_type: "application/pdf"
          )
          
          # Update the blob's created_at timestamp directly
          blob.update_column(:created_at, 2.minutes.ago)
          
          # If the application is persisted, use direct SQL
          if proof_review.application.persisted?
            ActiveStorage::Attachment.create(
              name: "income_proof",
              record_type: "Application",
              record_id: proof_review.application.id,
              blob_id: blob.id
            )
          else
            # If not persisted, use regular attach but in a safe way
            proof_review.application.income_proof.attach(blob)
          end
        ensure
          # Restore the thread variable
          Thread.current[:paper_application_context] = original_context
        end
      end
    end

    trait :with_residency_proof do
      proof_type { :residency }
      after(:build) do |proof_review|
        next if proof_review.application.residency_proof.attached?
        
        # Set the thread variable to disable callbacks during factory creation
        original_context = Thread.current[:paper_application_context]
        Thread.current[:paper_application_context] = true
        
        begin
          fixture_dir = Rails.root.join("test", "fixtures", "files")
          file_path = fixture_dir.join("test_residency_proof.pdf")
          unless File.exist?(file_path)
            File.write(file_path, "test content for residency proof")
          end
          
          # Create a blob directly and then create the attachment record directly
          blob = ActiveStorage::Blob.create_and_upload!(
            io: File.open(file_path),
            filename: "test_residency_proof.pdf",
            content_type: "application/pdf"
          )
          
          # Update the blob's created_at timestamp directly
          blob.update_column(:created_at, 2.minutes.ago)
          
          # If the application is persisted, use direct SQL
          if proof_review.application.persisted?
            ActiveStorage::Attachment.create(
              name: "residency_proof",
              record_type: "Application",
              record_id: proof_review.application.id,
              blob_id: blob.id
            )
          else
            # If not persisted, use regular attach but in a safe way
            proof_review.application.residency_proof.attach(blob)
          end
        ensure
          # Restore the thread variable
          Thread.current[:paper_application_context] = original_context
        end
      end
    end
  end
end
