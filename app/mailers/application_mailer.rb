class ApplicationMailer < ActionMailer::Base
  include MessageStreamable
  helper :mailer

  default(
    from: "no_reply@mdmat.org",
    reply_to: "no_reply@mdmat.org"
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
                  ENV.fetch("MAILER_HOST", "morning-dawn-84330-f594822dd77d.herokuapp.com")
    end
  end

  def set_common_variables
    @current_year = Time.current.year
    @organization_name = "Maryland Accessible Telecommunications Program"
    @organization_email = "no_reply@mdmat.org"
    @organization_website = "https://mdmat.org"
  end
end
