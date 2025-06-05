class AddProofStatusToApplications < ActiveRecord::Migration[8.0]
  def up
    # Add the columns with defaults
    add_column :applications, :income_proof_status, :integer, default: 0, null: false
    add_column :applications, :residency_proof_status, :integer, default: 0, null: false

    # Add indexes for better query performance
    add_index :applications, :income_proof_status, name: 'idx_applications_on_income_proof_status'
    add_index :applications, :residency_proof_status, name: 'idx_applications_on_residency_proof_status'

    # Add CHECK constraints for valid enum values (PostgreSQL specific)
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
    end
  end

  def down
    # Remove CHECK constraints first (PostgreSQL specific)
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      execute <<-SQL
        ALTER TABLE applications
        DROP CONSTRAINT IF EXISTS income_proof_status_check;
      SQL

      execute <<-SQL
        ALTER TABLE applications
        DROP CONSTRAINT IF EXISTS residency_proof_status_check;
      SQL
    end

    # Remove indexes
    remove_index :applications, name: 'idx_applications_on_income_proof_status', if_exists: true
    remove_index :applications, name: 'idx_applications_on_residency_proof_status', if_exists: true

    # Remove columns
    remove_column :applications, :income_proof_status
    remove_column :applications, :residency_proof_status
  end
end
