class CreatePrintQueueItems < ActiveRecord::Migration[8.0]
  def change
    create_table :print_queue_items do |t|
      t.integer :letter_type, null: false
      t.integer :status, default: 0, null: false
      t.references :constituent, null: false, foreign_key: { to_table: :users }
      t.references :application, null: true, foreign_key: true
      t.references :admin, null: true, foreign_key: { to_table: :users }
      t.datetime :printed_at

      t.timestamps
    end
  end
end
