class CreateProofSubmissionAudits < ActiveRecord::Migration[8.0]
  def change
    create_table :proof_submission_audits do |t|
      t.references :application, null: false, foreign_key: true, index: true
      t.references :user, null: false, foreign_key: true, index: true
      t.string :proof_type, null: false
      t.string :ip_address
      t.jsonb :metadata, null: false, default: {}
      t.integer :submission_method, null: false, default: 0
      t.string :inbound_email_id

      t.timestamps

      # Performance indices
      t.index :submission_method
      t.index :inbound_email_id
      t.index :created_at
      t.index [ :user_id, :created_at ], name: 'idx_proof_audits_user_created'
      t.index [ :application_id, :created_at ], name: 'idx_proof_audits_app_created'
    end
  end
end
