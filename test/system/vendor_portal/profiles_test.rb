require 'application_system_test_case'

module VendorPortal
  class ProfilesTest < ApplicationSystemTestCase
    setup do
      @vendor_user = create(:vendor_user) # Use FactoryBot to create a vendor user
      system_test_sign_in(@vendor_user) # Use the system test authentication helper
    end

    test 'updating a Vendor profile and accepting terms' do
      visit edit_vendor_profile_url

      assert_selector 'h1', text: 'Edit Vendor Profile'

      fill_in 'Business name', with: 'Updated Vendor Business Name'
      check 'I accept the terms and conditions' # Assuming the checkbox label is "I accept the terms and conditions"

      click_on 'Update Profile'

      assert_text 'Profile was successfully updated.' # Assuming a success message is displayed
      assert_current_path vendor_dashboard_path # Assuming redirection to dashboard after update

      # Verify the changes were saved by visiting the edit page again or checking the database
      @vendor_user.reload
      assert_equal 'Updated Vendor Business Name', @vendor_user.business_name
      assert_not_nil @vendor_user.terms_accepted_at

      # Optional: Visit the edit page again to confirm the saved values in the form
      visit edit_vendor_profile_url
      assert_selector "input[value='Updated Vendor Business Name']"
      assert find_field('I accept the terms and conditions').checked?
    end

    # Add more system tests for other profile-related scenarios as needed
  end
end
