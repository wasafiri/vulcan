require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "gets help" do
    get pages_help_url
    assert_response :success
  end

  test "gets how_it_works" do
    get pages_how_it_works_url
    assert_response :success
  end

  test "gets eligibility" do
    get pages_eligibility_url
    assert_response :success
  end

  test "gets apply" do
    get pages_apply_url
    assert_response :success
  end

  test "gets contact" do
    get pages_contact_url
    assert_response :success
  end
end
