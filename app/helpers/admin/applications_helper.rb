module Admin::ApplicationsHelper
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
end
