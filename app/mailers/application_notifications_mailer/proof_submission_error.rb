class ApplicationNotificationsMailer < ApplicationMailer
  def proof_submission_error(constituent, application, error_type, message)
    @constituent = constituent
    @application = application
    @error_type = error_type
    @message = message

    mail(
      to: @constituent.email,
      subject: "Error Processing Your Proof Submission"
    )
  end
end
