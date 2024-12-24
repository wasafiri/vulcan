require "test_helper"

describe Evaluator::EvaluationsController do
  it "gets index" do
    get evaluator_evaluations_index_url
    must_respond_with :success
  end

  it "gets show" do
    get evaluator_evaluations_show_url
    must_respond_with :success
  end

  it "gets new" do
    get evaluator_evaluations_new_url
    must_respond_with :success
  end

  it "gets create" do
    get evaluator_evaluations_create_url
    must_respond_with :success
  end

  it "gets edit" do
    get evaluator_evaluations_edit_url
    must_respond_with :success
  end

  it "gets update" do
    get evaluator_evaluations_update_url
    must_respond_with :success
  end

  it "gets submit_request" do
    get evaluator_evaluations_submit_request_url
    must_respond_with :success
  end

  it "gets request_additional_info" do
    get evaluator_evaluations_request_additional_info_url
    must_respond_with :success
  end

  it "gets pending" do
    get evaluator_evaluations_pending_url
    must_respond_with :success
  end

  it "gets completed" do
    get evaluator_evaluations_completed_url
    must_respond_with :success
  end
end
