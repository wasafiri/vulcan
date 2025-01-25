class AddFieldsToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :manufacturer, :string
    add_column :products, :model_number, :string
    add_column :products, :features, :text
    add_column :products, :compatibility_notes, :text
    add_column :products, :documentation_url, :string
  end
end
