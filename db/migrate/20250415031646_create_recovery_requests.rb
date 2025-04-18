class CreateRecoveryRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :recovery_requests do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status
      t.text :details
      t.string :ip_address
      t.text :user_agent

      t.timestamps
    end
  end
end
