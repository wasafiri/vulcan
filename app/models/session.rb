# frozen_string_literal: true

class Session < ApplicationRecord
  # associates the session with a user
  belongs_to :user

  # validate the presence and uniqueness of the session token, ip address, user_agent
  validates :session_token, presence: true, uniqueness: true
  validates :ip_address, presence: true
  validates :user_agent, presence: true

  # generate a session token before validation on create
  before_validation :generate_session_token, on: :create

  # sets the user agent and IP address before validation on create
  before_validation :set_user_agent_and_ip, on: :create

  private

  def generate_session_token
    return if session_token.present?

    loop do
      self.session_token = SecureRandom.urlsafe_base64(32)
      break unless Session.exists?(session_token: session_token)
    end
  end

  def set_user_agent_and_ip
    return if user_agent.present? && ip_address.present?

    self.user_agent = Current.user_agent
    self.ip_address = Current.ip_address
  end
end
