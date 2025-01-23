class AddMetadataToEvents < ActiveRecord::Migration[8.0]
  def change
    add_column :events, :metadata, :jsonb, default: {}, null: false
    add_index :events, :metadata, using: :gin
  end
end
