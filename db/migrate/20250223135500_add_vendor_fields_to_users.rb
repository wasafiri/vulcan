class AddVendorFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :business_name, :string
    add_column :users, :business_tax_id, :string
    add_column :users, :terms_accepted_at, :datetime

    add_index :users, :business_name
    add_index :users, :business_tax_id
  end
end
