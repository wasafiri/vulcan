require "test_helper"

class Admin::PoliciesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_david)
    @policy = Policy.create!(key: "max_training_sessions", value: 3)

    @headers = {
      "HTTP_USER_AGENT" => "Rails Testing",
      "REMOTE_ADDR" => "127.0.0.1"
    }

    post sign_in_path,
      params: { email: @admin.email, password: "password123" },
      headers: @headers

    assert_response :redirect
    follow_redirect!
  end

  def test_should_get_index
    get admin_policies_path
    assert_response :success
  end

  def test_should_update_policy
    patch admin_policies_path, params: {
      policies: {
        "#{@policy.id}": {
          id: @policy.id,
          value: "42"
        }
      }
    }
    assert_redirected_to admin_policies_path
    assert_equal "Policies updated successfully.", flash[:notice]
  end

  def test_should_create_policy
    assert_difference("Policy.count") do
      post admin_policies_path, params: {
        policy: {
          key: "new_test_policy",
          value: "42"
        }
      }
    end
    assert_redirected_to admin_policies_path
    assert_equal "Policy 'new_test_policy' created successfully.", flash[:notice]
  end
end
