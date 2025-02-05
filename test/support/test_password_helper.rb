require "bcrypt"

module TestPasswordHelper
  # Default plain-text password used in tests
  def default_password
    "password123"
  end

  # Generates the password digest using User.digest
  def default_password_digest
    User.digest(default_password)
  end
end
