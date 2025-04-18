class AddResolvedFieldsToRecoveryRequests < ActiveRecord::Migration[8.0]
  def change
    add_column :recovery_requests, :resolved_at, :datetime
    add_column :recovery_requests, :resolved_by_id, :integer
  end
end
