class MedicalProviderMailer < ApplicationMailer
  def request_certification(application)
    @application = application
    @constituent = application.user

    mail(
      to: @application.medical_provider_email,
      subject: "Disability Certification Request for #{@constituent.full_name}"
    )
  end
end
