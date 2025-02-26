class CreateInvoices < ActiveRecord::Migration[8.0]
  def change
    create_table :invoices do |t|
      t.references :vendor, null: false, foreign_key: { to_table: :users }
      t.datetime :start_date, null: false
      t.datetime :end_date, null: false
      t.decimal :total_amount, precision: 10, scale: 2, null: false, default: 0
      t.integer :status, null: false, default: 0
      t.datetime :payment_date
      t.string :payment_reference
      t.text :notes
      t.string :invoice_number, null: false

      t.timestamps

      t.index :status
      t.index :invoice_number, unique: true
      t.index :payment_date
      t.index [ :vendor_id, :status ]
      t.index [ :start_date, :end_date ]
    end
  end
end
