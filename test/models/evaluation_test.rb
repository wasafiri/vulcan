# frozen_string_literal: true

require 'test_helper'

class EvaluationTest < ActiveSupport::TestCase
  test 'creates a valid evaluation' do
    evaluation = create(:evaluation)
    assert evaluation.valid?
    assert_equal :pending, evaluation.status
  end

  test 'creates a completed evaluation' do
    evaluation = create(:evaluation, :completed)
    assert evaluation.valid?
    assert_equal :completed, evaluation.status
    assert evaluation.report_submitted
  end

  test 'creates an evaluation with custom attendees' do
    evaluation = create(:evaluation, :with_custom_attendees)
    assert_equal 1, evaluation.attendees.size
    assert_equal 'Alice Johnson', evaluation.attendees.first['name']
  end

  test 'creates an evaluation with mobile devices' do
    evaluation = create(:evaluation, :with_mobile_devices)
    assert_equal 2, evaluation.products_tried.size
    assert_equal 'iPhone', evaluation.products_tried.first['product_id'].name
    assert_equal 'Pixel', evaluation.products_tried.second['product_id'].name
  end
end
