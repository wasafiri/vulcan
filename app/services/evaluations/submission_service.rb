module Evaluations
  class SubmissionService
    def initialize(evaluation, params)
      @evaluation = evaluation
      @params = params
    end

    def submit
      ApplicationRecord.transaction do
        @evaluation.assign_attributes(submission_params)
        @evaluation.status = :completed
        @evaluation.save!
        notify_constituent
        update_application_status
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
        :location,
        :notes,
        :status,
        recommended_product_ids: [],
        attendees: [ :name, :relationship ],
        products_tried: [ :product_id, :reaction ]
      )
    end

    def notify_constituent
      EvaluatorMailer.evaluation_submission_confirmation(@evaluation).deliver_now
    end

    def update_application_status
      @evaluation.application.update!(status: :evaluation_completed)
    end
  end
end
