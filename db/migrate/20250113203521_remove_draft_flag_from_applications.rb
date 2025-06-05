class RemoveDraftFlagFromApplications < ActiveRecord::Migration[8.0]
  def up
    # Check if the draft column exists before working with it
    return unless column_exists?(:applications, :draft)

    # Update all draft applications to have draft status (status = 0)
    # Update all non-draft applications with in_progress status to keep in_progress (status = 1)
    connection.update("UPDATE applications SET status = 0 WHERE draft = #{connection.quote(true)}")
    connection.update("UPDATE applications SET status = 1 WHERE draft = #{connection.quote(false)} AND status = 1")

    remove_column :applications, :draft
  end

  def down
    add_column :applications, :draft, :boolean, default: true

    # Restore draft flag based on status (0 = draft, everything else = not draft)
    connection.update("UPDATE applications SET draft = #{connection.quote(true)} WHERE status = 0")
    connection.update("UPDATE applications SET draft = #{connection.quote(false)} WHERE status != 0")
  end
end
