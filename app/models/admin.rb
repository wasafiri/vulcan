# This is an alias to the Users::Admin class for backward compatibility
# Future code should use Users::Admin directly
class Admin < User
  def self.method_missing(method, *args, &block)
    Users::Admin.send(method, *args, &block)
  end

  def method_missing(method, *args, &block)
    Users::Admin.instance_method(method).bind(self).call(*args, &block) if Users::Admin.instance_methods.include?(method)
  end
  
  def can_manage_users?
    true
  end
end

# Explicitly load the real implementation to avoid loading order issues
require_dependency 'users/admin'
