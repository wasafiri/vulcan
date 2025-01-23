class Current < ActiveSupport::CurrentAttributes
  attribute :user, :user_agent, :ip_address

  class << self
    def set(request, user)
      self.user_agent = request.user_agent
      self.ip_address = request.remote_ip
      self.user = user
    end
  end
end
