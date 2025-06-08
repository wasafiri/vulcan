class DropProofSubmissionAudits < ActiveRecord::Migration[8.0]
  def change
    drop_table :proof_submission_audits
  end
end
