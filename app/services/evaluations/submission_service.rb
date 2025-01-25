module Evaluations
  class SubmissionService
    def initialize(evaluation, params)
      @evaluation = evaluation
      @params = params
    end

    def submit
      ApplicationRecord.transaction do
        @evaluation.update!(submission_params)
        notify_constituent
        update_application
      end
      true
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "Evaluation submission failed: #{e.message}"
      false
    end

    private

    def submission_params
      @params.require(:evaluation).permit(
        :needs,
        :recommended_product_ids,
        :recommended_accessory_ids,
        :evaluation_datetime,
        :location,
        :attendees,
        :products_tried,
        :notes
      )
    end

    def notify_constituent
      EvaluatorMailer.evaluation_submission_confirmation(@evaluation).deliver_later
    end

    def update_application
      @evaluation.application.update!(last_evaluation_completed_at: Time.current)
    end
  end
end
