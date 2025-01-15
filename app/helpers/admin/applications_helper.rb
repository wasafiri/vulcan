module Admin::ApplicationsHelper
  def proof_status_class(status)
    case status
    when "not_reviewed"
      "text-yellow-500"
    when "approved"
      "text-green-500"
    when "rejected"
      "text-red-500"
    else
      "text-gray-500"
    end
  end

  def proof_status_badge(status)
    case status
    when "not_reviewed"
      "bg-yellow-100 text-yellow-800"
    when "approved"
      "bg-green-100 text-green-800"
    when "rejected"
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def application_status_badge(status)
    case status
    when "in_progress"
      "bg-yellow-100 text-yellow-800"
    when "approved"
      "bg-green-100 text-green-800"
    when "rejected"
      "bg-red-100 text-red-800"
    when "needs_information"
      "bg-blue-100 text-blue-800"
    when "reminder_sent"
      "bg-purple-100 text-purple-800"
    when "awaiting_documents"
      "bg-orange-100 text-orange-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def status_background_color(status)
    case status&.to_sym
    when :approved
      "bg-green-50"
    when :rejected
      "bg-red-50"
    when :needs_information
      "bg-yellow-50"
    else
      "bg-gray-50"
    end
  end

  def training_session_status_badge(status)
    case status.to_s
    when "scheduled"
      "bg-blue-100 text-blue-800"
    when "completed"
      "bg-green-100 text-green-800"
    when "cancelled"
      "bg-red-100 text-red-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  def evaluation_status_badge(status)
    case status.to_s
    when "pending"
      "bg-yellow-100 text-yellow-800"
    when "in_progress"
      "bg-blue-100 text-blue-800"
    when "completed"
      "bg-green-100 text-green-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end
end
