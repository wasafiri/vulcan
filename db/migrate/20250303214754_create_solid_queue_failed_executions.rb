class CreateSolidQueueFailedExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_queue_failed_executions do |t|
      t.references :job, null: false, foreign_key: { to_table: :solid_queue_jobs, on_delete: :cascade }
      t.references :process, foreign_key: { to_table: :solid_queue_processes, on_delete: :nullify }
      t.text :error
      t.text :backtrace
      t.datetime :failed_at, null: false
      t.timestamps

      t.index :failed_at
    end
  end
end
