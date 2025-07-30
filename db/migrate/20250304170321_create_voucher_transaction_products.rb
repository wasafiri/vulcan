class CreateVoucherTransactionProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :voucher_transaction_products do |t|
      t.references :voucher_transaction, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.index %i[voucher_transaction_id product_id], name: 'idx_on_voucher_txn_product'

      t.timestamps
    end
  end
end
