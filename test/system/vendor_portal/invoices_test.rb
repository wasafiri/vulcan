require 'application_system_test_case'

module VendorPortal
  class InvoicesTest < ApplicationSystemTestCase
    setup do
      @vendor_user = create(:vendor_user) # Use FactoryBot to create a vendor user
      system_test_sign_in(@vendor_user) # Use the system test authentication helper
    end

    test 'viewing the Vendor Invoices index' do
      # Create multiple invoices for the vendor
      create_list(:invoice, 5, vendor: @vendor_user)

      visit vendor_invoices_url

      assert_selector 'h1', text: 'Vendor Invoices'
      assert_selector 'table.invoices tbody tr', count: 5 # Verify all 5 invoices are displayed

      # Add assertions to check for specific content within the invoice list, e.g., invoice numbers, amounts, statuses
      @vendor_user.invoices.each do |invoice| # Iterate over the user's invoices association
        assert_text "##{invoice.id}"
        assert_text "$#{'%.2f' % invoice.total_amount}" # Verify corrected amount display
        assert_text invoice.status.humanize # Verify status display
      end
    end

    test 'viewing an individual Vendor Invoice' do
      invoice = create(:invoice, vendor: @vendor_user, total_amount: 99.99, status: :invoice_paid, gad_invoice_reference: 'GAD-TEST-REF') # Corrected status and added gad_invoice_reference

      visit vendor_invoice_url(invoice)

      assert_selector 'h1', text: "Invoice ##{invoice.id}"
      assert_text 'Total Amount: $99.99' # Verify corrected amount display on show page
      assert_text 'Status: Paid' # Verify status display on show page

      # Add more assertions to check for other details on the invoice show page
    end

    test 'attempting to view an invoice belonging to another vendor' do
      another_vendor_user = create(:vendor_user)
      invoice_from_another_vendor = create(:invoice, vendor: another_vendor_user)

      visit vendor_invoice_url(invoice_from_another_vendor)

      # Assuming the application redirects or shows an error page for unauthorized access
      assert_text "The page you were looking for doesn't exist." # Assuming a standard Rails 404 page message
      assert_current_path '/404' # Assuming redirection to a 404 page
    end

    # Add more system tests for filtering, sorting, or other invoice index/show page features as needed.
  end
end
