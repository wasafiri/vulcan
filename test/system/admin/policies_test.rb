require "application_system_test_case"

class Admin::PoliciesTest < ApplicationSystemTestCase
  test "voucher policies exist with correct values" do
    # Create voucher policies
    Policy.find_or_create_by!(key: "voucher_value_hearing_disability") do |p|
      p.value = 500
    end

    Policy.find_or_create_by!(key: "voucher_value_vision_disability") do |p|
      p.value = 500
    end

    Policy.find_or_create_by!(key: "voucher_value_speech_disability") do |p|
      p.value = 500
    end

    Policy.find_or_create_by!(key: "voucher_value_mobility_disability") do |p|
      p.value = 500
    end

    Policy.find_or_create_by!(key: "voucher_value_cognition_disability") do |p|
      p.value = 500
    end

    Policy.find_or_create_by!(key: "voucher_validity_period_months") do |p|
      p.value = 6
    end

    Policy.find_or_create_by!(key: "voucher_minimum_redemption_amount") do |p|
      p.value = 10
    end

    # Verify policies exist with correct values
    assert_equal 500, Policy.find_by(key: "voucher_value_hearing_disability").value
    assert_equal 500, Policy.find_by(key: "voucher_value_vision_disability").value
    assert_equal 500, Policy.find_by(key: "voucher_value_speech_disability").value
    assert_equal 500, Policy.find_by(key: "voucher_value_mobility_disability").value
    assert_equal 500, Policy.find_by(key: "voucher_value_cognition_disability").value
    assert_equal 6, Policy.find_by(key: "voucher_validity_period_months").value
    assert_equal 10, Policy.find_by(key: "voucher_minimum_redemption_amount").value
  end

  test "voucher policies can be updated" do
    # Create admin user
    admin = create(:admin)

    # Create voucher policies
    hearing_policy = Policy.find_or_create_by!(key: "voucher_value_hearing_disability") do |p|
      p.value = 500
    end

    # Update policy value
    hearing_policy.updated_by = admin
    hearing_policy.update!(value: 600)

    # Verify policy value was updated
    assert_equal 600, Policy.find_by(key: "voucher_value_hearing_disability").value
  end

  test "admin can view voucher policies in UI" do
    # Create admin user and sign in
    admin = create(:admin)
    sign_in(admin)

    # Create voucher policies
    Policy.find_or_create_by!(key: "voucher_value_hearing_disability") { |p| p.value = 500 }
    Policy.find_or_create_by!(key: "voucher_value_vision_disability") { |p| p.value = 500 }
    Policy.find_or_create_by!(key: "voucher_validity_period_months") { |p| p.value = 6 }
    Policy.find_or_create_by!(key: "voucher_minimum_redemption_amount") { |p| p.value = 10 }

    # Visit admin policies page
    visit admin_policies_path

    # Verify we're on the policies page
    assert_selector "h1", text: "System Policies"

    # Check for basic voucher-related text
    assert_text "Hearing"
    assert_text "Vision"
    assert_text "Validity Period Months"
    assert_text "Minimum Redemption Amount"
  end

  test "admin can update voucher policy value and see change in history" do
    # Create admin user and sign in
    admin = create(:admin)
    admin.update!(first_name: "Test", last_name: "Admin")
    sign_in(admin)

    # Create voucher policy with initial value
    hearing_policy = Policy.find_or_create_by!(key: "voucher_value_hearing_disability") do |p|
      p.value = 500
    end

    # Visit admin policies page
    visit admin_policies_path

    # Find the hearing disability input field and update its value
    within "tr", text: "Hearing" do
      fill_in "policies[#{hearing_policy.id}][value]", with: 600
    end

    # Submit the form
    click_button "Update Policies"

    # Verify success message
    assert_text "Policies updated successfully"

    # Verify the value was updated in the database
    assert_equal 600, Policy.find_by(key: "voucher_value_hearing_disability").value

    # Verify the change appears in the Recent Policy Changes section
    within "h2", text: "Recent Policy Changes" do
      within(:xpath, "./following-sibling::div") do
        within "table" do
          assert_text "Voucher Value Hearing Disability"
          assert_text "Test Admin"
          assert_text "$500.00"
          assert_text "$600.00"
        end
      end
    end
  end
end
