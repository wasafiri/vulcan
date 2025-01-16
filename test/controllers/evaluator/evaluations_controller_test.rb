require "test_helper"

class Evaluator::EvaluationsControllerTest < ActionDispatch::IntegrationTest
  test "gets index" do
    get evaluator_evaluations_index_url
    assert_response :success
  end

  test "gets show" do
    get evaluator_evaluations_show_url
    assert_response :success
  end

  test "gets new" do
    get evaluator_evaluations_new_url
    assert_response :success
  end

  test "gets create" do
    get evaluator_evaluations_create_url
    assert_response :success
  end

  test "gets edit" do
    get evaluator_evaluations_edit_url
    assert_response :success
  end

  test "gets update" do
    get evaluator_evaluations_update_url
    assert_response :success
  end

  test "gets submit_request" do
    get evaluator_evaluations_submit_request_url
    assert_response :success
  end

  test "gets request_additional_info" do
    get evaluator_evaluations_request_additional_info_url
    assert_response :success
  end

  test "gets pending" do
    get evaluator_evaluations_pending_url
    assert_response :success
  end

  test "gets completed" do
    get evaluator_evaluations_completed_url
    assert_response :success
  end
end
