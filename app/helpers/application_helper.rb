module ApplicationHelper
  def dashboard_path_for(user)
    return root_path unless user
    
    case
    when user.admin?
      admin_root_path
    when user.evaluator?
      evaluator_dashboard_path
    when user.vendor?
      vendor_dashboard_path
    else
      root_path
    end
  end

  def application_status_color(status)
    case status.to_sym
    when :pending
      'bg-yellow-100 text-yellow-800'
    when :approved
      'bg-green-100 text-green-800'
    when :rejected
      'bg-red-100 text-red-800'
    when :needs_information
      'bg-orange-100 text-orange-800'
    when :reminder_sent
      'bg-blue-100 text-blue-800'
    when :in_progress
      'bg-purple-100 text-purple-800'
    when :awaiting_documents
      'bg-indigo-100 text-indigo-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end
