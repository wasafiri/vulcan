class FixEmailUniquenessForDependents < ActiveRecord::Migration[8.0]
  def up
    # First, rollback the problematic migration changes
    # Remove the indexes that were created in the previous migration
    remove_index :users, name: 'index_users_on_email_with_dependent_exception' if index_exists?(:users, :email, name: 'index_users_on_email_with_dependent_exception')
    remove_index :users, name: 'index_users_on_email_non_unique' if index_exists?(:users, :email, name: 'index_users_on_email_non_unique')
    
    # Add back a simple unique index on email
    # We'll handle the dependent email sharing logic in the application layer instead
    add_index :users, :email, unique: true, name: 'index_users_on_email' unless index_exists?(:users, :email, name: 'index_users_on_email')
  end

  def down
    # If we need to rollback this fix, remove the simple index
    remove_index :users, name: 'index_users_on_email' if index_exists?(:users, :email, name: 'index_users_on_email')
  end
end
