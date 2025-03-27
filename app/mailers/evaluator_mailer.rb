# frozen_string_literal: true

class EvaluatorMailer < ApplicationMailer
  def new_evaluation_assigned
    @evaluation = params[:evaluation]
    @evaluator = @evaluation.evaluator
    @constituent = @evaluation.constituent
    @application = @evaluation.application

    mail(
      to: @evaluator.email,
      subject: "New Evaluation Assigned - Application ##{@application.id}",
      message_stream: 'notifications'
    )
  end

  def evaluation_submission_confirmation(evaluation)
    @evaluation = evaluation
    @constituent = evaluation.constituent
    @application = evaluation.application

    # Create a letter if the constituent prefers print communications
    if @constituent.communication_preference == 'letter'
      Letters::LetterGeneratorService.new(
        template_type: 'evaluation_submitted',
        data: { evaluation: @evaluation },
        constituent: @constituent,
        application: @application
      ).queue_for_printing
    end

    mail(
      to: @constituent.email,
      subject: "Your Evaluation has been Submitted - Application ##{@application.id}",
      message_stream: 'notifications'
    )
  end
end
