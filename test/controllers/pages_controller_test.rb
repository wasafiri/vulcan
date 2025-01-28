require "test_helper"

class PagesControllerTest < ActionDispatch::IntegrationTest
  test "should get how it works" do
    get how_it_works_path
    assert_response :success
  end

  test "should get help" do
    get help_path
    assert_response :success
  end

  test "should get contact" do
    get contact_path
    assert_response :success
  end

  test "should get apply" do
    get apply_path
    assert_response :success
  end

  test "should get eligibility" do
    get eligibility_path
    assert_response :success
  end
end
