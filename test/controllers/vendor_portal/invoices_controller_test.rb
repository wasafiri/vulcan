# frozen_string_literal: true

require 'test_helper'

module VendorPortal
  class InvoicesControllerTest < ActionDispatch::IntegrationTest
    # Assuming AuthenticationTestHelper exists and provides sign_in_with_headers and assert_authenticated
    # If not, this helper might need to be created or adjusted based on the actual authentication setup.
    # For now, we'll assume it exists as per the user's example.
    include AuthenticationTestHelper
    include ActionView::Helpers::NumberHelper # Include number helpers for currency formatting

    setup do
      @vendor_user = create(:vendor_user) # Use FactoryBot to create a vendor user
      sign_in_with_headers(@vendor_user) # Sign in the vendor user
      assert_authenticated(@vendor_user) # Verify authentication
      # Create multiple invoices for the vendor in the setup to ensure consistent test data
      @invoices = create_list(:invoice, 5, vendor: @vendor_user)
    end

    test 'should show invoices index' do
      # Assuming vendor_invoices_url route exists
      get vendor_invoices_url
      assert_response :success
      # Add assertions to check for specific content on the invoices index page
      assert_select 'h1', 'My Invoices' # Corrected assertion to match view
      # Assert presence of invoice data by checking for list items within the unordered list
      assert_select 'ul[role="list"].divide-y.divide-gray-200 li', count: @invoices.count
    end

    test 'should show individual invoice' do
      # Assuming a vendor invoice exists and vendor_invoice_url route exists
      invoice = create(:invoice, vendor: @vendor_user, total_amount: 123.45) # Create an invoice associated with the vendor user
      get vendor_invoice_url(invoice)
      assert_response :success
      # Add assertions to check for content on the invoice show page
      assert_select 'h1', "Invoice ##{invoice.id}"
      assert_select 'dd', text: number_to_currency(invoice.total_amount) # Updated assertion to match view
      # Add more assertions to check for other invoice details displayed on the page
    end

    test 'should not show invoice belonging to another vendor' do
      another_vendor_user = create(:vendor_user)
      invoice_from_another_vendor = create(:invoice, vendor: another_vendor_user)

      get vendor_invoice_url(invoice_from_another_vendor)
      # Assuming the application redirects or returns a 404 for unauthorized access
      assert_redirected_to vendor_invoices_url # Updated assertion to expect redirect
    end

    # Add more tests as needed for filtering, sorting, or other invoice index/show page features.
  end
end
