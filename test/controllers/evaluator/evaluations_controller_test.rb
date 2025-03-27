# frozen_string_literal: true

module Evaluators
  class EvaluationsControllerTest < ActionDispatch::IntegrationTest
    def setup
      @evaluator = users(:evaluator_betsy)
      sign_in(@evaluator)
      @product = products(:ipad_air)
      @evaluation = create(:evaluation, evaluator: @evaluator)
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
      assert_changes '@evaluation.reload.status', from: 'pending', to: 'completed' do
        post submit_report_evaluators_evaluation_path(@evaluation), params: {
          evaluation: {
            needs: 'Final needs assessment',
            notes: 'Final evaluation notes',
            location: 'Final location',
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
end
