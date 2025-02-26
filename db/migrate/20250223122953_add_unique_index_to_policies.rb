class AddUniqueIndexToPolicies < ActiveRecord::Migration[8.0]
  def change
    add_index :policies, :key, unique: true
  end
end
