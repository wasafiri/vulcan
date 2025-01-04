class CreateSolidQueueTables < ActiveRecord::Migration[8.0]
  def change
    create_table :solid_queue_tables do |t|
      t.timestamps
    end
  end
end
