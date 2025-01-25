class AddDeviceTypesArrayToProducts < ActiveRecord::Migration[8.0]
  def change
    remove_column :products, :device_type, :string
    add_column :products, :device_types, :text, array: true, default: []
    add_index :products, :device_types, using: :gin
  end
end
