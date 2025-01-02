class MigrateMedicalProvidersToUsers < ActiveRecord::Migration[8.0]
  def up
    drop_table :medical_providers
  end

  def down
    create_table :medical_providers do |t|
      t.string :name
      t.string :phone
      t.string :fax
      t.string :email
      t.text :address

      t.timestamps
    end
  end
end
