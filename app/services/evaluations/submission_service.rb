# frozen_string_literal: true

module Evaluations
  class SubmissionService
    def initialize(evaluation, params)
      @evaluation = evaluation
      @params = params
    end

    def submit
      ApplicationRecord.transaction do
        @evaluation.assign_attributes(submission_params)
        @evaluation.status = :completed # Directly set the intended final status

        # --- Targeted Debugging ---
        Rails.logger.info '--- Debugging before save! ---'
        Rails.logger.info "Attempting to save evaluation ID: #{@evaluation.id}"
        Rails.logger.info "Current status before save: #{@evaluation.status}"
        Rails.logger.info "Changes before save: #{@evaluation.changes.inspect}"
        is_valid = @evaluation.validate # Manually trigger validation
        Rails.logger.info "Is valid according to .validate?: #{is_valid}"
        Rails.logger.info "Validation errors before save: #{@evaluation.errors.full_messages.join(', ')}"
        # Debugging removed

        @evaluation.save! # Attempt to save
        notify_constituent
        # update_application_status # Removed - Application status should update via its own callbacks/logic
      end
      true
    rescue ActiveRecord::RecordInvalid => e
      # Log actual validation errors if save! fails
      Rails.logger.error "Evaluation submission FAILED for ID #{@evaluation&.id}: #{e.message}"
      Rails.logger.error "Validation errors: #{@evaluation&.errors&.full_messages&.join(', ')}"
      false
    end

    private

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

    # Removed update_application_status method
  end
end
