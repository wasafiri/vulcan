module ApplicationHelper
  include Pagy::Frontend
  include BadgeHelper

  def dashboard_path_for(user)
    return root_path unless user
    case user.type
    when "Admin" then admin_root_path
    when "Evaluator" then evaluator_root_path
    when "Vendor" then vendor_root_path
    else root_path
    end
  end

  def application_status_badge(application)
    content_tag(:span,
      badge_label_for(:application, application.status),
      class: "px-2 py-1 text-sm font-medium rounded-full #{badge_class_for(:application, application.status)}"
    )
  end

  def proof_status_badge(proof_type, status)
    content_tag(:span,
      badge_label_for(:proof, status),
      class: "px-2 py-1 text-sm font-medium rounded-full #{badge_class_for(:proof, status)}"
    )
  end

  def evaluation_status_badge(evaluation)
    content_tag(:span,
      badge_label_for(:evaluation, evaluation.status),
      class: "px-2 py-1 text-sm font-medium rounded-full #{badge_class_for(:evaluation, evaluation.status)}"
    )
  end

  def training_session_status_badge(session)
    content_tag(:span,
      badge_label_for(:training_session, session.status),
      class: "px-2 py-1 text-sm font-medium rounded-full #{badge_class_for(:training_session, session.status)}"
    )
  end
end
