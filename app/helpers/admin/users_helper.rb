module Admin::UsersHelper
  def capability_description(capability)
    case capability
    when 'can_evaluate'
      'Can perform evaluations and submit assessment reports'
    when 'can_train'
      'Can conduct training sessions and manage training materials'
    else
      'Additional system capability'
    end
  end

  def role_description(role)
    case role
    when 'Admin'
      'Full system access and management capabilities'
    when 'Evaluator'
      'Can perform evaluations and manage assessment data'
    when 'Constituent'
      'Standard user access to system features'
    when 'Vendor'
      'Vendor-specific access and management features'
    else
      'Standard system access'
    end
  end
end
