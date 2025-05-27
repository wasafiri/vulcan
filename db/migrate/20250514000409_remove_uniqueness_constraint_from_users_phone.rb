# frozen_string_literal: true

class RemoveUniquenessConstraintFromUsersPhone < ActiveRecord::Migration[8.0]
  def up
    # Remove the existing unique index
    remove_index :users, name: 'index_users_on_phone'

    # Add back the same index but without the uniqueness constraint
    add_index :users, :phone, where: 'phone IS NOT NULL'
  end

  def down
    # Remove the non-unique index
    remove_index :users, :phone

    # Add back the unique index
    add_index :users, :phone, unique: true, where: 'phone IS NOT NULL'
  end
end
