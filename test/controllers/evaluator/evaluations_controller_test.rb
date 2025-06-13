# frozen_string_literal: true

require 'test_helper'

# This is a controller test for the Evaluators::EvaluationsController
class EvaluationsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @evaluator = create(:evaluator)
    sign_in_for_controller_test(@evaluator)
    @product = create(:product, name: 'iPad Air')
    @evaluation = create(:evaluation, evaluator: @evaluator, status: :scheduled)
  end

  test 'gets pending' do
    get pending_evaluators_evaluations_path
    assert_response :success
  end

  test 'gets completed' do
    get completed_evaluators_evaluations_path
    assert_response :success
  end

  test 'submits report' do
    assert_changes '@evaluation.reload.status', from: 'scheduled', to: 'completed' do
      post submit_report_evaluators_evaluation_path(@evaluation), params: {
        evaluation: {
          needs: 'Final needs assessment',
          notes: 'Final evaluation notes',
          location: 'Final location',
          evaluation_date: Time.current,
          recommended_product_ids: [@product.id],
          products_tried: [{
            product_id: @product.id,
            reaction: 'Positive'
          }],
          attendees: [{
            name: 'Test User',
            relationship: 'Self'
          }]
        }
      }
    end

    assert_redirected_to evaluators_evaluation_path(@evaluation)
  end
end
