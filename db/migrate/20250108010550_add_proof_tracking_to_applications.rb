class AddProofTrackingToApplications < ActiveRecord::Migration[8.0]
  def change
    # Create proof_reviews table
    create_table :proof_reviews do |t|
      t.references :application, null: false, foreign_key: true
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.string :proof_type, null: false # 'income' or 'residency'
      t.string :status, null: false # 'approved' or 'rejected'
      t.text :rejection_reason
      t.string :submission_method # 'web', 'email', 'scanned'
      t.datetime :reviewed_at, null: false
      t.timestamps
    end

    # Add tracking columns to applications
    add_column :applications, :total_rejections, :integer, default: 0, null: false
    add_column :applications, :last_proof_submitted_at, :datetime
    add_column :applications, :needs_review_since, :datetime

    # Add indexes for common queries
    add_index :proof_reviews, [ :application_id, :proof_type, :created_at ]
    add_index :proof_reviews, [ :admin_id, :created_at ]
    add_index :proof_reviews, :status
    add_index :proof_reviews, :reviewed_at
    add_index :proof_reviews, [ :application_id, :proof_type, :status ]

    # Indexes for applications table
    add_index :applications, :needs_review_since
    add_index :applications, :last_proof_submitted_at
    add_index :applications, :total_rejections
    add_index :applications, [ :status, :needs_review_since ]
  end
end
