# frozen_string_literal: true

class TestController < ApplicationController
  def auth_status
    render json: {
      authenticated: current_user.present?,
      user_email: current_user&.email,
      user_id: current_user&.id,
      user_type: current_user&.type
    }
  end
end
