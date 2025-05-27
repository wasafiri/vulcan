class RemoveUniqueIndexFromUsersEmail < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    # Remove unique index on email and recreate non-unique index concurrently
    remove_index :users, :email
    add_index :users, :email, algorithm: :concurrently
  end

  def down
    # Revert to unique index on email
    remove_index :users, :email
    add_index :users, :email, unique: true, algorithm: :concurrently
  end
end
