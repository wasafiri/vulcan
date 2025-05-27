# frozen_string_literal: true

# Test controller for handling test-specific routes
# Only available in test environment
class TestController < ApplicationController
  skip_before_action :authenticate_user!

  # Simple endpoint for testing authentication status
  # Used by test helpers to verify authentication works correctly
  def auth_status
    status = if current_user
               { authenticated: true, user_id: current_user.id, email: current_user.email }
             else
               { authenticated: false }
             end

    respond_to do |format|
      format.html { render plain: status.to_json }
      format.json { render json: status }
    end
  end
end
