class CreateApplicationNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :application_notes do |t|
      t.references :application, null: false, foreign_key: true
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.text :content, null: false
      t.boolean :internal_only, default: true

      t.timestamps
    end
  end
end
