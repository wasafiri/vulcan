class AddTimestampsToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :approved_at, :datetime
    add_column :invoices, :payment_recorded_at, :datetime

    add_index :invoices, :approved_at
    add_index :invoices, :payment_recorded_at
  end
end
