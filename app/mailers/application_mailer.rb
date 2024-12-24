class ApplicationMailer < ActionMailer::Base
  default from: ENV['ELASTIC_EMAIL_FROM'],
          reply_to: ENV['ELASTIC_EMAIL_REPLY_TO']
          
  layout 'mailer'
  
  before_action :set_default_host_url
  
  private
  
  def set_default_host_url
    @host_url = ENV['MAILER_HOST']
  end
end
