class AddCancellationAndProductToTrainingSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :training_sessions, :cancelled_at, :datetime
    add_column :training_sessions, :cancellation_reason, :text
    add_reference :training_sessions, :product_trained_on, null: true, foreign_key: { to_table: :products }
  end
end
