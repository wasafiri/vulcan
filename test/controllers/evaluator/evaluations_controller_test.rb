require "test_helper"

class Evaluator::EvaluationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @evaluator = create(:evaluator)
    sign_in(@evaluator)
    @evaluation = create(:evaluation, evaluator: @evaluator)
  end

  test "gets index" do
    get evaluators_evaluations_path
    assert_response :success
  end

  test "gets show" do
    get evaluators_evaluation_path(@evaluation)
    assert_response :success
  end

  test "gets new" do
    get new_evaluators_evaluation_path
    assert_response :success
  end

  test "creates evaluation" do
    assert_difference("Evaluation.count", 1) do
      post evaluators_evaluations_path, params: { evaluation: {
        constituent_id: create(:constituent).id
        # Add other required attributes
      } }
    end
    assert_redirected_to evaluators_evaluation_path(Evaluation.last)
  end

  test "gets edit" do
    get edit_evaluators_evaluation_path(@evaluation)
    assert_response :success
  end

  test "updates evaluation" do
    patch evaluators_evaluation_path(@evaluation), params: { evaluation: { status: "completed" } }
    assert_redirected_to evaluators_evaluation_path(@evaluation)
  end

  test "submits report" do
    post submit_report_evaluators_evaluation_path(@evaluation)
    assert_redirected_to evaluators_evaluation_path(@evaluation)
  end

  test "requests additional info" do
    post request_additional_info_evaluators_evaluation_path(@evaluation)
    assert_redirected_to evaluators_evaluation_path(@evaluation)
  end

  test "gets pending" do
    get pending_evaluators_evaluations_path
    assert_response :success
  end

  test "gets completed" do
    get completed_evaluators_evaluations_path
    assert_response :success
  end
end
