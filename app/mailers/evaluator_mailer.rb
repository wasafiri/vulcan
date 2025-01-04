class EvaluatorMailer < ApplicationMailer
  def new_evaluation_assigned
    @evaluation = params[:evaluation]
    @constituent = params[:constituent]
    @evaluator = @evaluation.evaluator

    mail(
      to: @evaluator.email,
      subject: "New Evaluation Assigned - #{@constituent.full_name}",
      track_opens: true,
      message_stream: "notifications"
    )
  end
end
