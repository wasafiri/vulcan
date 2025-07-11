class AddChangeTypeToApplicationStatusChanges < ActiveRecord::Migration[8.0]
  def change
    add_column :application_status_changes, :change_type, :string
  end
end
