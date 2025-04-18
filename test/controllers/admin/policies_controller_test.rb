# frozen_string_literal: true

require 'test_helper'

module Admin
  class PoliciesControllerTest < ActionDispatch::IntegrationTest
    def setup
      @admin = create(:admin)
      @policy = Policy.create!(key: 'max_training_sessions', value: 3)
      sign_in_as(@admin) # Use standard helper
    end

    def test_should_get_index
      get admin_policies_path
      assert_response :success
      assert_select 'h1', text: 'System Policies'
      assert_select "form[action='/admin/policies'][method='post']" do
        assert_select "input[name='_method'][value='patch']"
      end
    end

  def test_should_see_edit_form_on_index
    # Policies are edited directly on the index page
    get admin_policies_path
    assert_response :success
    assert_select "form[action='/admin/policies'][method='post']" do
      assert_select "input[name='_method'][value='patch']"
    end
  end

  def test_should_get_edit
    get edit_admin_policy_path(@policy)
    assert_response :success
    assert_select 'h1', text: 'Edit System Policies'
  end

    def test_should_get_changes
      get changes_admin_policies_path
      assert_response :success
    end

    def test_should_update_policy
      patch admin_policy_path(@policy), params: {
        policy: {
          value: '42'
        }
      }
      assert_redirected_to admin_policies_path
      @policy.reload
      assert_equal '42', @policy.value.to_s
    end

    def test_should_create_policy
      assert_difference('Policy.count') do
        post admin_policies_path, params: {
          policy: {
            key: 'new_test_policy',
            value: '42'
          }
        }
      end
      assert_redirected_to admin_policies_path
      assert_equal "Policy 'new_test_policy' created successfully.", flash[:notice]
    end
  end
end
