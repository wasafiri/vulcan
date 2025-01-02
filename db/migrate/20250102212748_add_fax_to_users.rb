class AddFaxToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :fax, :string
  end
end
