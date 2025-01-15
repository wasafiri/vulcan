# db/migrate/20250107150000_create_email_templates.rb
class CreateEmailTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :email_templates do |t|
      t.string :name, null: false
      t.string :subject
      t.text :body
      t.text :variables, array: true, default: []
      t.references :updated_by, foreign_key: { to_table: :users }
      t.timestamps

      t.index :name, unique: true
    end
  end
end
