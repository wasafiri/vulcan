class CreateEvaluations < ActiveRecord::Migration[8.0]
  def change
    create_table :evaluations do |t|
      t.references :evaluator, null: false, foreign_key: { to_table: :users }
      t.references :constituent, null: false, foreign_key: { to_table: :users }
      t.datetime :evaluation_date
      t.integer :evaluation_type
      t.boolean :report_submitted
      t.text :notes

      t.timestamps
    end
  end
end
