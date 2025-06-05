class AddDefaultsToProofStatusInApplications < ActiveRecord::Migration[8.0]
  def up
    # Check if columns exist before attempting to modify them
    if column_exists?(:applications, :income_proof_status)
      # Backfill existing nils to default value (0 => not_reviewed) using connection directly
      connection.update('UPDATE applications SET income_proof_status = 0 WHERE income_proof_status IS NULL')

      # Add default values and set NOT NULL constraints
      change_column_default :applications, :income_proof_status, from: nil, to: 0
      change_column_null :applications, :income_proof_status, false, 0
    end

    return unless column_exists?(:applications, :residency_proof_status)

    # Backfill existing nils to default value (0 => not_reviewed) using connection directly
    connection.update('UPDATE applications SET residency_proof_status = 0 WHERE residency_proof_status IS NULL')

    # Add default values and set NOT NULL constraints
    change_column_default :applications, :residency_proof_status, from: nil, to: 0
    change_column_null :applications, :residency_proof_status, false, 0
  end

  def down
    # Revert changes if rolling back
    if column_exists?(:applications, :income_proof_status)
      change_column_default :applications, :income_proof_status, from: 0, to: nil
      change_column_null :applications, :income_proof_status, true, nil
    end

    return unless column_exists?(:applications, :residency_proof_status)

    change_column_default :applications, :residency_proof_status, from: 0, to: nil
    change_column_null :applications, :residency_proof_status, true, nil
  end
end
