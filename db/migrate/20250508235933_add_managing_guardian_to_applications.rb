class AddManagingGuardianToApplications < ActiveRecord::Migration[8.0]
  def change
    add_reference :applications, :managing_guardian, null: true, foreign_key: { to_table: :users }
  end
end
