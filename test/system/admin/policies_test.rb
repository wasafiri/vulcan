require "application_system_test_case"

class Admin::PoliciesTest < ApplicationSystemTestCase
  def setup
    @admin = users(:admin_david)
    @policy = Policy.create!(key: "max_training_sessions", value: 3)
    sign_in(@admin)
  end

  test "should display policies page" do
    visit admin_policies_path
    assert_selector "h1", text: "System Policies"
  end

  test "should display policy change history" do
    visit changes_admin_policies_path
    assert_selector "h1", text: "Policy Change History"
    assert_no_text "Content missing"
  end
end
