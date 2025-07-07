# frozen_string_literal: true

require 'application_system_test_case'

module VendorPortal
  class InvoicesTest < ApplicationSystemTestCase
    setup do
      @vendor_user = create(:vendor_user)
      system_test_sign_in(@vendor_user)
    end

    test 'viewing the Vendor Invoices index' do
      # Create multiple invoices for the vendor with proper status
      invoices = create_list(:invoice, 3, vendor: @vendor_user, status: 'invoice_pending')

      visit vendor_invoices_url
      wait_for_turbo
      clear_pending_connections_fast # Clear any pending connections after navigation

      # The actual heading is "My Invoices" not "Vendor Invoices"
      assert_selector 'h1', text: 'My Invoices'
      
      # Check for invoice cards (not table rows)
      assert_selector 'ul[role="list"] li', count: 3

      # Verify invoice content appears in the list
      invoices.each do |invoice|
        assert_text "Invoice ##{invoice.id}"
        assert_text number_to_currency(invoice.total_amount)
        assert_text invoice.status.humanize
      end
      
      # Verify navigation elements
      assert_link 'Back to Dashboard'
    end

    test 'viewing an individual Vendor Invoice' do
      invoice = create(:invoice, 
        vendor: @vendor_user, 
        total_amount: 99.99, 
        status: 'invoice_paid',
        gad_invoice_reference: 'GAD-TEST-REF'
      )

      visit vendor_invoice_url(invoice)
      wait_for_turbo
      clear_pending_connections_fast # Clear any pending connections after navigation

      # Check for the actual content structure
      assert_text "Invoice ##{invoice.id}"
      assert_text number_to_currency(99.99)
      assert_text 'Paid' # Status display
      
      # Check for GAD reference if it exists
      if invoice.gad_invoice_reference.present?
        assert_text invoice.gad_invoice_reference
      end
    end

    test 'attempting to view an invoice belonging to another vendor' do
      another_vendor_user = create(:vendor_user)
      invoice_from_another_vendor = create(:invoice, vendor: another_vendor_user)

      visit vendor_invoice_url(invoice_from_another_vendor)
      wait_for_turbo
      clear_pending_connections_fast # Clear any pending connections after navigation

      # Should redirect back to invoices index with alert
      assert_current_path vendor_invoices_path
      assert_text 'Invoice not found'
    end

    private

    def number_to_currency(amount)
      # Simple currency formatting for test assertions
      "$#{'%.2f' % amount}"
    end
  end
end
