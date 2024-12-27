module ApplicationHelper
  include Pagy::Frontend

  def dashboard_path_for(user)
    return root_path unless user

    case user.type
    when "Admin" then admin_root_path
    when "Evaluator" then evaluator_root_path
    when "Vendor" then vendor_root_path
    else root_path
    end
  end

  def application_status_badge(status)
    {
      pending: "bg-yellow-100 text-yellow-800",
      approved: "bg-green-100 text-green-800",
      rejected: "bg-red-100 text-red-800",
      needs_information: "bg-orange-100 text-orange-800",
      reminder_sent: "bg-blue-100 text-blue-800",
      in_progress: "bg-purple-100 text-purple-800",
      awaiting_documents: "bg-indigo-100 text-indigo-800"
    }[status.to_sym] || "bg-gray-100 text-gray-800"
  end
end
