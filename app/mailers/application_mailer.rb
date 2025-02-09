class ApplicationMailer < ActionMailer::Base
  default(
    from: "info@mdmat.org",
    reply_to: "info@mdmat.org"
  )

  layout "mailer"
  before_action :set_default_host_url

  private

  def set_default_host_url
    @host_url = if Rails.env.development?
                  "localhost:3000"
    else
      ENV.fetch("MAILER_HOST")
    end
  end
end
