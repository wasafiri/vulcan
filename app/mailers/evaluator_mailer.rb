class EvaluatorMailer < ApplicationMailer
  def new_evaluation_assigned
    @evaluation = params[:evaluation]
    @evaluator = @evaluation.evaluator
    @constituent = @evaluation.constituent
    @application = @evaluation.application

    mail(
      to: @evaluator.email,
      subject: "New Evaluation Assigned - Application ##{@application.id}"
    )
  end

  def evaluation_submission_confirmation(evaluation)
    @evaluation = evaluation
    @constituent = evaluation.constituent
    @application = evaluation.application

    mail(
      to: @constituent.email,
      subject: "Your Evaluation has been Submitted - Application ##{@application.id}"
    )
  end
end
