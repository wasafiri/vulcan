class ModifyEmailUniquenessForDependents < ActiveRecord::Migration[8.0]
  def change
    # Remove the existing unique index on email
    remove_index :users, name: 'index_users_on_email'

    # Add a partial unique index that only applies to non-dependent users
    # This allows dependents to share emails with guardians while maintaining
    # uniqueness for all other users
    add_index :users, :email,
              name: 'index_users_on_email_with_dependent_exception',
              unique: true,
              where: 'NOT EXISTS (SELECT 1 FROM guardian_relationships WHERE guardian_relationships.dependent_id = users.id)'

    # Add a non-unique index on email for query performance on all users
    add_index :users, :email, name: 'index_users_on_email_non_unique'
  end
end
