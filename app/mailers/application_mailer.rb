class ApplicationMailer < ActionMailer::Base
  default(
    from: ENV.fetch("ELASTIC_EMAIL_FROM"),
    reply_to: ENV.fetch("ELASTIC_EMAIL_REPLY_TO")
  )

  layout "mailer"

  before_action :set_default_host_url

  private

  def set_default_host_url
    @host_url = ENV.fetch("MAILER_HOST")
  end
end
