# frozen_string_literal: true

require 'application_system_test_case'

module Vendor
  class InterfaceTest < ApplicationSystemTestCase
    setup do
      @vendor = create(:vendor, :approved)
      @voucher = create(:voucher, :active)
      sign_in @vendor
    end

    test 'viewing dashboard' do
      visit vendor_dashboard_path

      assert_selector 'h1', text: 'Vendor Dashboard'
      assert_selector "[data-test-id='pending-payment']"
      assert_selector "[data-test-id='monthly-total']"
      assert_selector "[data-test-id='recent-transactions']"
    end

    test 'uploading W9 form' do
      visit edit_vendor_profile_path

      # NOTE: In a real application, we would use a PDF file.
      # For testing purposes, we're using a text file to avoid
      # binary file handling complexities in the test environment.
      attach_file 'vendor[w9_form]',
                  file_fixture('sample_w9.txt'),
                  make_visible: true

      fill_in 'Business Name', with: 'Test Business'
      fill_in 'Tax ID (EIN/SSN)', with: '123456789'
      check 'I agree to the vendor terms and conditions'

      click_on 'Save Changes'

      assert_text 'Profile updated successfully'
      assert_selector "[data-test-id='w9-status']", text: 'Current W9 form'
    end

    test 'processing a valid voucher' do
      visit new_vendor_redemption_path

      fill_in 'Voucher Code', with: @voucher.code
      fill_in 'Amount', with: '50.00'

      click_on 'Process Voucher'

      assert_text 'Successfully processed voucher'
      assert_current_path vendor_dashboard_path
    end

    test 'attempting to process an invalid voucher' do
      visit new_vendor_redemption_path

      fill_in 'Voucher Code', with: 'INVALID-CODE'
      fill_in 'Amount', with: '50.00'

      click_on 'Process Voucher'

      assert_text 'Invalid voucher code'
      assert_selector "[data-test-id='error-message']"
    end

    test 'viewing transaction history' do
      create_list(:voucher_transaction, 3,
                  vendor: @vendor,
                  status: :transaction_completed)

      visit vendor_transactions_path

      assert_selector 'h1', text: 'Transaction History'
      assert_selector '.transaction-row', count: 3

      # Test filtering
      select 'Today', from: 'Time Period'
      click_on 'Apply Filters'

      assert_selector "[data-test-id='filtered-results']"
    end

    test 'generating transaction report' do
      create_list(:voucher_transaction, 3,
                  vendor: @vendor,
                  status: :transaction_completed)

      visit vendor_transactions_path(format: :pdf)

      assert_equal 'application/pdf', page.response_headers['Content-Type']
    end

    test 'exporting transactions to CSV' do
      create_list(:voucher_transaction, 3,
                  vendor: @vendor,
                  status: :transaction_completed)

      visit vendor_transactions_path(format: :csv)

      assert_equal 'text/csv', page.response_headers['Content-Type']
      assert_match 'Date,Voucher Code,Amount,Status,Reference', page.body
    end

    test 'viewing invoice details' do
      invoice = create(:invoice, :paid,
                       vendor: @vendor,
                       gad_invoice_reference: 'GAD-123456',
                       check_number: 'CHK-789')
      create(:voucher_transaction,
             vendor: @vendor,
             invoice: invoice,
             status: :transaction_completed)

      visit vendor_invoice_path(invoice)

      assert_selector 'h1', text: "Invoice ##{invoice.invoice_number}"
      assert_selector "[data-test-id='invoice-total']", text: number_to_currency(invoice.total_amount)
      assert_selector "[data-test-id='invoice-status']", text: 'Paid'
      assert_selector "[data-test-id='gad-reference']", text: 'GAD-123456'
      assert_selector "[data-test-id='check-number']", text: 'CHK-789'
      assert_selector '.transaction-row'
    end

    test 'viewing pending invoice' do
      invoice = create(:invoice, :pending,
                       vendor: @vendor,
                       total_amount: 500.00)
      create(:voucher_transaction,
             vendor: @vendor,
             invoice: invoice,
             status: :transaction_pending)

      visit vendor_invoice_path(invoice)

      assert_selector "[data-test-id='invoice-status']", text: 'Pending'
      assert_selector "[data-test-id='pending-notice']",
                      text: 'This invoice is pending review and approval'
    end

    test 'viewing approved invoice' do
      invoice = create(:invoice, :approved,
                       vendor: @vendor,
                       total_amount: 500.00)
      create(:voucher_transaction,
             vendor: @vendor,
             invoice: invoice,
             status: :transaction_pending)

      visit vendor_invoice_path(invoice)

      assert_selector "[data-test-id='invoice-status']", text: 'Approved'
      assert_selector "[data-test-id='approved-notice']",
                      text: 'This invoice has been approved and sent to GAD for processing'
    end

    test 'custom date range filtering' do
      visit vendor_transactions_path

      select 'Custom Range', from: 'Time Period'

      assert_selector "[data-date-range-target='customRange']"

      fill_in 'Start Date', with: 1.month.ago.strftime('%Y-%m-%d')
      fill_in 'End Date', with: Time.current.strftime('%Y-%m-%d')

      click_on 'Apply Filters'

      assert_selector "[data-test-id='filtered-results']"
    end

    test 'dashboard shows appropriate alerts' do
      @vendor.update!(status: :vendor_pending)

      visit vendor_dashboard_path

      assert_selector "[data-test-id='pending-approval-alert']"
      assert_text 'Your account is currently under review'

      unless @vendor.w9_form.attached?
        assert_selector "[data-test-id='w9-required-alert']"
        assert_text 'Please upload your W9 form'
      end
    end
  end
end
