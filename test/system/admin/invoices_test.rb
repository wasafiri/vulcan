# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class InvoicesTest < ApplicationSystemTestCase
    include VoucherTestHelper

    setup do
      @admin = create(:admin)
      @vendor = create(:vendor, :approved)
      @invoice = create(:invoice, :pending, :with_transactions,
                        vendor: @vendor,
                        transaction_count: 2,
                        amount_per_transaction: 250.00)
      sign_in(@admin)
    end

    test 'viewing and approving invoice' do
      visit admin_invoices_path
      assert_selector '.invoice-row', count: 1
      assert_selector "[data-test-id='invoice-status']", text: 'Pending'

      click_on @invoice.invoice_number
      assert_selector 'h1', text: 'Invoice Details'

      click_on 'Approve Invoice'
      assert_selector "[data-test-id='invoice-status']", text: 'Approved'
      assert_text 'Invoice approved successfully'
    end

    test 'recording GAD payment details' do
      @invoice.update!(status: :invoice_approved)
      visit admin_invoice_path(@invoice)

      fill_in 'GAD Invoice Reference', with: 'GAD-123456'
      fill_in 'Check Number', with: 'CHK-789'
      fill_in 'Payment Notes', with: 'Payment processed by GAD'
      click_on 'Record Payment'

      assert_text 'Payment details recorded successfully'
      assert_invoice_paid(@invoice)
      assert_selector "[data-test-id='gad-reference']", text: 'GAD-123456'
    end

    test 'exporting paid invoices' do
      # Create some paid invoices
      create_list(:invoice, 3, :paid,
                  vendor: @vendor,
                  gad_invoice_reference: 'GAD-123456')

      visit admin_invoices_path
      select 'Paid', from: 'Status'
      click_on 'Apply Filters'

      click_on 'Export Batch'
      assert_valid_csv_response
    end

    test 'requires GAD reference for payment' do
      @invoice.update!(status: :invoice_approved)
      visit admin_invoice_path(@invoice)

      # Try to record payment without GAD reference
      fill_in 'Check Number', with: 'CHK-789'
      fill_in 'Payment Notes', with: 'Payment processed by GAD'
      click_on 'Record Payment'

      assert_text "GAD invoice reference can't be blank"
      assert_selector "[data-test-id='invoice-status']", text: 'Approved'

      # Now add GAD reference and try again
      fill_in 'GAD Invoice Reference', with: 'GAD-123456'
      click_on 'Record Payment'

      assert_invoice_paid(@invoice)
      assert_selector "[data-test-id='gad-reference']", text: 'GAD-123456'
    end
  end
end
