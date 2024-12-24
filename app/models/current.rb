class Current < ActiveSupport::CurrentAttributes
  attribute :user_agent, :ip_address

  class << self
    def set_attributes(request)
      self.user_agent = request.user_agent
      self.ip_address = request.remote_ip
    end
  end
end
