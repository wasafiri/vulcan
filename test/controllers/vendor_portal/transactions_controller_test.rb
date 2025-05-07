require 'test_helper'

module VendorPortal
  class TransactionsControllerTest < ActionDispatch::IntegrationTest
    # Assuming AuthenticationTestHelper exists and provides sign_in_with_headers and assert_authenticated
    # If not, this helper might need to be created or adjusted based on the actual authentication setup.
    # For now, we'll assume it exists as per the user's example.
    include AuthenticationTestHelper

    setup do
      @vendor_user = create(:vendor_user) # Use FactoryBot to create a vendor user
      sign_in_with_headers(@vendor_user) # Sign in the vendor user
      assert_authenticated(@vendor_user) # Verify authentication
    end

    test 'should show transactions index with pagination' do
      # Assuming vendor_transactions_url route exists
      # Create multiple transactions to test pagination
      create_list(:voucher_transaction, 30, vendor: @vendor_user)
      get vendor_transactions_url
      assert_response :success
      # Assert presence of transaction data and pagination links
      assert_select 'h1', 'Transaction History' # Updated assertion
      # Assert presence of the pagination nav element
      assert_select 'nav.flex.items-center.justify-between'
      # Assertions to check for the correct number of transactions per page (default is 20 for Pagy)
      assert_select 'table.min-w-full tbody tr', count: 20 # Expect 20 transactions on the first page
    end

    test 'should not show transactions belonging to another vendor' do
      another_vendor_user = create(:vendor_user)
      create_list(:voucher_transaction, 5, vendor: another_vendor_user)

      get vendor_transactions_url
      assert_response :success
      # Assert that only the current vendor's transactions are displayed
      # Since no transactions are created for the current vendor in this test, expect 0 rows.
      assert_select 'table.min-w-full tbody tr', count: 0
      # You might need more specific assertions to ensure the displayed transactions belong to @vendor_user
    end

    # Add more tests as needed for filtering, sorting, or other transaction index/report page features.
  end
end
