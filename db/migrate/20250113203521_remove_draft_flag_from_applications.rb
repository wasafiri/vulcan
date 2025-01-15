class RemoveDraftFlagFromApplications < ActiveRecord::Migration[8.0]
  def up
    # Update all draft applications to have draft status
    Application.where(draft: true).update_all(status: :draft)

    # Update all non-draft applications with in_progress status to keep in_progress
    Application.where(draft: false, status: :in_progress).update_all(status: :in_progress)

    remove_column :applications, :draft
  end

  def down
    add_column :applications, :draft, :boolean, default: true

    # Restore draft flag based on status
    Application.where(status: :draft).update_all(draft: true)
    Application.where.not(status: :draft).update_all(draft: false)
  end
end
