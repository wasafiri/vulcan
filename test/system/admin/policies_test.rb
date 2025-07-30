# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class PoliciesTest < ApplicationSystemTestCase
    def setup
      # Create admin user using proper factory
      @admin = create(:admin)

      # Create the policy that the test needs instead of assuming it exists
      @policy = Policy.find_or_create_by!(key: 'max_training_sessions') do |p|
        p.value = 3
      end

      # Set up FPL policies for the policies page to display
      setup_fpl_policies

      # Use proper system test authentication
      system_test_sign_in(@admin)
    end

    test 'should display policies page' do
      visit admin_policies_path
      wait_for_turbo

      assert_selector 'h1', text: 'System Policies'

      # Verify some content is displayed (FPL section should be there)
      assert_text 'Federal Poverty Level (FPL) Settings'
    end

    test 'should display policy change history' do
      visit changes_admin_policies_path
      wait_for_turbo

      assert_selector 'h1', text: 'Policy Change History'
      assert_no_text 'Content missing'

      # Should have a back link to policies
      assert_link 'Back to Policies'
    end
  end
end
