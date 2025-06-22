# frozen_string_literal: true

module Users
  # Service object to handle updating a user's password.
  class PasswordUpdateService < BaseService
    def initialize(user, password_challenge, new_password, new_password_confirmation)
      super()
      @user = user
      @password_challenge = password_challenge
      @new_password = new_password
      @new_password_confirmation = new_password_confirmation
      @errors = []
    end

    def call
      return fail_with_error('User not found.') unless @user

      return fail_with_error('Current password is incorrect.') unless @user.authenticate(@password_challenge)

      return fail_with_error('New password and confirmation do not match.') unless @new_password == @new_password_confirmation

      if @user.update(password: @new_password, force_password_change: false)
        success_result(message: 'Password successfully updated.')
      else
        fail_with_error('Unable to update password. Please check requirements.', @user.errors.full_messages)
      end
    end

    private

    def fail_with_error(message, details = [])
      @errors << message
      @errors.concat(details) if details.present?
      BaseService::Result.new(success: false, message: @errors.join(', '))
    end

    def success_result(data = {})
      BaseService::Result.new(success: true, data: data, message: 'Password successfully updated.')
    end
  end
end
