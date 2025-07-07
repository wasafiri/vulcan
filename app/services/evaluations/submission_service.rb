# frozen_string_literal: true

module Evaluations
  class SubmissionService
    def initialize(evaluation, params)
      @evaluation = evaluation
      @params = params
    end

    def submit
      ApplicationRecord.transaction do
        prepare_evaluation
        save_evaluation!
        notify_constituent
      end
      true
    rescue ActiveRecord::RecordInvalid => e
      handle_record_invalid(e)
      false
    end

    private

    def prepare_evaluation
      @evaluation.assign_attributes(submission_params)
      @evaluation.status = :completed # Directly set the intended final status
    end

    def save_evaluation!
      @evaluation.save! # Attempt to save
    end

    def handle_record_invalid(exception)
      Rails.logger.error "Evaluation submission FAILED for ID #{@evaluation&.id}: #{exception.message}"
      validation_errors = @evaluation&.errors&.full_messages
      Rails.logger.error "Validation errors: #{validation_errors&.join(', ')}" if validation_errors.present?
    end

    def submission_params
      @params.require(:evaluation).permit(
        :needs,
        :location,
        :notes,
        :evaluation_date,
        recommended_product_ids: [],
        attendees: %i[name relationship],
        products_tried: %i[product_id reaction]
      )
    end

    def notify_constituent
      EvaluatorMailer.evaluation_submission_confirmation(@evaluation).deliver_later
    end
  end
end
