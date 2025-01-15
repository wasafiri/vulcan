class RenameAttachmentStatusToProofStatusInApplications < ActiveRecord::Migration[8.0]
  def change
    if column_exists?(:applications, :income_attachment_status) && !column_exists?(:applications, :income_proof_status)
      rename_column :applications, :income_attachment_status, :income_proof_status
    end

    if column_exists?(:applications, :residency_attachment_status) && !column_exists?(:applications, :residency_proof_status)
      rename_column :applications, :residency_attachment_status, :residency_proof_status
    end
  end
end
