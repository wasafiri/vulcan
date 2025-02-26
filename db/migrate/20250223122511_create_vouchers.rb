class CreateVouchers < ActiveRecord::Migration[8.0]
  def change
    create_table :vouchers do |t|
      t.string :code, null: false
      t.decimal :initial_value, precision: 10, scale: 2, null: false
      t.decimal :remaining_value, precision: 10, scale: 2, null: false
      t.integer :status, default: 0, null: false
      t.references :application, null: false, foreign_key: true
      t.references :vendor, foreign_key: { to_table: :users }
      t.datetime :issued_at
      t.datetime :redeemed_at
      t.datetime :last_used_at
      t.references :invoice, foreign_key: true
      t.text :notes

      t.timestamps

      t.index :code, unique: true
      t.index :status
      t.index :issued_at
      t.index [ :vendor_id, :status ]
    end
  end
end
