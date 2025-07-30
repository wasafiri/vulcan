class CreateVoucherTransactions < ActiveRecord::Migration[8.0]
  def change
    create_table :voucher_transactions do |t|
      t.references :voucher, null: false, foreign_key: true
      t.references :vendor, null: false, foreign_key: { to_table: :users }
      t.references :invoice, foreign_key: true
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.integer :transaction_type, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :processed_at
      t.text :notes
      t.string :reference_number

      t.timestamps

      t.index :transaction_type
      t.index :status
      t.index :processed_at
      t.index :reference_number
      t.index %i[vendor_id status]
      t.index %i[voucher_id transaction_type]
    end
  end
end
