class User < ApplicationRecord
  has_secure_password

  # associations
  has_many :sessions, dependent: :destroy
  has_many :received_notifications, class_name: "Notification", foreign_key: :recipient_id, dependent: :destroy
  has_many :applications, foreign_key: :user_id

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }

  validates :first_name, :last_name, presence: true

  def full_name
    [ first_name, last_name ].compact.join(" ")
  end

  def track_sign_in!(ip)
    update(
      last_sign_in_at: Time.current,
      last_sign_in_ip: ip,
      failed_attempts: 0
    )
  end

  # define authenticate_by method as provided by authentication-zero
  def self.authenticate_by(email:, password:)
    user = find_by(email: email)
    user&.authenticate(password)
  end

  # role check methods
  def admin?
    is_a?(Admin)
  end

  def constituent?
    is_a?(Constituent)
  end

  def evaluator?
    is_a?(Evaluator)
  end

  def vendor?
    is_a?(Vendor)
  end

  def medical_provider?
    is_a?(MedicalProvider)
  end

  def generate_password_reset_token!
    update(
      reset_password_token: SecureRandom.urlsafe_base64,
      reset_password_sent_at: Time.current
    )
  end

  def clear_reset_password_token!
    update(
      reset_password_token: nil,
      reset_password_sent_at: nil
    )
  end
end
