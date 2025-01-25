class AddDetailsToEvaluations < ActiveRecord::Migration[8.0]
  def change
    add_column :evaluations, :needs, :text
    add_column :evaluations, :location, :string
    add_column :evaluations, :attendees, :jsonb, default: []
    add_column :evaluations, :products_tried, :jsonb, default: []
  end
end
