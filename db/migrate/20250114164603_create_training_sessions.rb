class CreateTrainingSessions < ActiveRecord::Migration[8.0]
  def change
    create_table :training_sessions do |t|
      t.references :application, null: false, foreign_key: true
      t.references :trainer, null: false, foreign_key: { to_table: :users }
      t.datetime :scheduled_for
      t.datetime :completed_at
      t.integer :status, default: 0
      t.text :notes

      t.timestamps
    end
  end
end
