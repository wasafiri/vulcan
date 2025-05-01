# frozen_string_literal: true

class AddUniqueIndexToUsersPhone < ActiveRecord::Migration[8.0]
  def change
    # Add a unique index to the phone column in the users table.
    # Allow null values, as phone might not be mandatory.
    # Use 'lower(phone)' if you want case-insensitive uniqueness,
    # but given the formatting logic, direct uniqueness should be fine.
    add_index :users, :phone, unique: true, where: 'phone IS NOT NULL'
  end
end
