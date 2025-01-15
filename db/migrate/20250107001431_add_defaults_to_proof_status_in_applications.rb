class AddDefaultsToProofStatusInApplications < ActiveRecord::Migration[8.0]
  def up
    # Backfill existing nils to default value (0 => not_reviewed)
    Application.where(income_proof_status: nil).update_all(income_proof_status: 0)
    Application.where(residency_proof_status: nil).update_all(residency_proof_status: 0)

    # Add default values and set NOT NULL constraints
    change_column_default :applications, :income_proof_status, from: nil, to: 0
    change_column_null :applications, :income_proof_status, false, 0

    change_column_default :applications, :residency_proof_status, from: nil, to: 0
    change_column_null :applications, :residency_proof_status, false, 0
  end

  def down
    # Revert changes if rolling back
    change_column_default :applications, :income_proof_status, from: 0, to: nil
    change_column_null :applications, :income_proof_status, true, nil

    change_column_default :applications, :residency_proof_status, from: 0, to: nil
    change_column_null :applications, :residency_proof_status, true, nil
  end
end
