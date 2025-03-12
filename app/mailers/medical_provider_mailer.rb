class MedicalProviderMailer < ApplicationMailer
  use_message_stream :transactional
  def request_certification(application)
    @application = application
    @constituent = application.user

    mail(
      to: @application.medical_provider_email,
      subject: "Disability Certification Request for #{@constituent.full_name}"
    )
  end
end
