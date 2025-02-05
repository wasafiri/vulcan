require "test_helper"

class Admin::ReportsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_david)

    # Set standard test headers
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
    get admin_reports_path
    assert_response :success
  end
end
