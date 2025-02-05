require "test_helper"

class Admin::PoliciesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_david)
    @policy = create(:policy)

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

  def test_should_get_edit
    get edit_admin_policy_path
    assert_response :success
  end

  def test_should_update_policy
    patch update_admin_policy_path, params: {
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
end
