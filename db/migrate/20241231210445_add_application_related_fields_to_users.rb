class AddApplicationRelatedFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :is_guardian, :boolean, default: false
    add_column :users, :guardian_relationship, :string
    add_reference :users, :guardian, foreign_key: { to_table: :users }

    create_table :medical_professionals do |t|
      t.string :name
      t.string :phone
      t.string :fax
      t.string :email
      t.text :address
      t.timestamps
    end
  end
end
