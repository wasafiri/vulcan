class ApplicationMailer < ActionMailer::Base
  helper :mailer

  default(
    from: "info@mdmat.org",
    reply_to: "info@mdmat.org"
  )

  layout "mailer"
  before_action :set_default_host_url
  before_action :set_common_variables

  private

  def set_default_host_url
    @host_url = if Rails.env.development?
                  "localhost:3000"
    elsif Rails.env.test?
                  "example.com"
    else
                  ENV.fetch("MAILER_HOST")
    end
  end

  def set_common_variables
    @current_year = Time.current.year
    @organization_name = "MDMAT Program"
    @organization_email = "info@mdmat.org"
    @organization_website = "https://mdmat.org"
  end
end
