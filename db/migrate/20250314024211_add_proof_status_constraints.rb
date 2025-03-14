class AddProofStatusConstraints < ActiveRecord::Migration[7.0]
  def up
    # Make sure income_proof_status and residency_proof_status cannot be NULL
    change_column_null :applications, :income_proof_status, false, 0  # Default to not_reviewed (0)
    change_column_null :applications, :residency_proof_status, false, 0  # Default to not_reviewed (0)
    
    # Add CHECK constraints for valid values (PostgreSQL specific)
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      # Check that proof statuses are valid enum values (0=not_reviewed, 1=approved, 2=rejected)
      execute <<-SQL
        ALTER TABLE applications
        ADD CONSTRAINT income_proof_status_check
        CHECK (income_proof_status IN (0, 1, 2));
      SQL
      
      execute <<-SQL
        ALTER TABLE applications
        ADD CONSTRAINT residency_proof_status_check
        CHECK (residency_proof_status IN (0, 1, 2));
      SQL
      
      # Add index to improve performance of queries that filter by proof status
      add_index :applications, :income_proof_status, name: 'idx_applications_on_income_proof_status'
      add_index :applications, :residency_proof_status, name: 'idx_applications_on_residency_proof_status'
    end
  end

  def down
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      # Remove CHECK constraints
      execute <<-SQL
        ALTER TABLE applications
        DROP CONSTRAINT IF EXISTS income_proof_status_check;
      SQL
      
      execute <<-SQL
        ALTER TABLE applications
        DROP CONSTRAINT IF EXISTS residency_proof_status_check;
      SQL
      
      # Remove indexes
      remove_index :applications, name: 'idx_applications_on_income_proof_status', if_exists: true
      remove_index :applications, name: 'idx_applications_on_residency_proof_status', if_exists: true
    end
    
    # Remove NOT NULL constraints
    change_column_null :applications, :income_proof_status, true
    change_column_null :applications, :residency_proof_status, true
  end
end
