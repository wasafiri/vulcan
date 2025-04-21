# frozen_string_literal: true

module Users
  class Administrator < User
    def can_manage_users?
      true
    end

    # Add any other methods that might exist in Users::Admin
  end
end
