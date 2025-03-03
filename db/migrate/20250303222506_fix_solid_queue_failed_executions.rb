class FixSolidQueueFailedExecutions < ActiveRecord::Migration[8.0]
  def up
    # First, update any existing records with null failed_at to use the created_at timestamp
    execute <<-SQL
      UPDATE solid_queue_failed_executions
      SET failed_at = created_at
      WHERE failed_at IS NULL
    SQL

    # Then, change the column to have a default value
    change_column_default :solid_queue_failed_executions, :failed_at, -> { 'CURRENT_TIMESTAMP' }
  end

  def down
    change_column_default :solid_queue_failed_executions, :failed_at, nil
  end
end
