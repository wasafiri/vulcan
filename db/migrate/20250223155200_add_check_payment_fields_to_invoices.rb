class AddCheckPaymentFieldsToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :check_number, :string
    add_column :invoices, :check_issued_at, :datetime
    add_column :invoices, :check_cashed_at, :datetime
    add_column :invoices, :check_cashed_by, :string
    add_column :invoices, :gad_invoice_reference, :string
    add_column :invoices, :payment_notes, :text

    add_index :invoices, :check_number
    add_index :invoices, :gad_invoice_reference
    add_index :invoices, :check_issued_at
    add_index :invoices, :check_cashed_at
  end
end
