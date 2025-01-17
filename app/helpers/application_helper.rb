module ApplicationHelper
  include Pagy::Frontend
  include BadgeHelper

  def dashboard_path_for(user)
    return root_path unless user

    case user.type
    when "Admin"     then admin_root_path
    when "Evaluator" then evaluator_root_path
    when "Vendor"    then vendor_root_path
    else root_path
    end
  end

  def application_status_badge(application)
    render partial: "shared/status_badge", locals: {
      type: :application,
      status: application.status,
      label: application.status.to_s.humanize
    }
  end
end
