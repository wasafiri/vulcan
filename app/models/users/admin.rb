# frozen_string_literal: true

module Users
  class Admin < User
    def can_manage_users?
      true
    end
  end
end
