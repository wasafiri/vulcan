class CreateApplicationStatusChanges < ActiveRecord::Migration[8.0]
  def change
    create_table :application_status_changes do |t|
      t.references :application, null: false, foreign_key: true
      t.references :user, foreign_key: true
      t.string :from_status, null: false
      t.string :to_status, null: false
      t.datetime :changed_at, null: false
      t.text :notes
      t.json :metadata

      t.timestamps
    end

    add_index :application_status_changes, :changed_at
  end
end
