class Admin < User
  def can_manage_users?
    true
  end
end
