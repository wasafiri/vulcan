# frozen_string_literal: true

# Application helper methods for common view functionality and formatting.
module ApplicationHelper
  include ConstituentPortal::ActivityHelper
  include ActiveStorageHelper
  include Pagy::Frontend
  include BadgeHelper

  def flash_class_for(flash_type)
    case flash_type
    when 'notice' then 'bg-green-100 border border-green-400 text-green-700'
    when 'alert' then 'bg-red-100 border border-red-400 text-red-700'
    else 'bg-blue-100 border border-blue-400 text-blue-700'
    end
  end

  def dashboard_path_for(user)
    return root_path unless user

    case user.type
    when 'Admin' then admin_applications_path
    when 'Evaluator' then evaluator_root_path
    when 'Vendor' then vendor_root_path
    else root_path
    end
  end

  def application_status_badge(application)
    content_tag(:span,
                badge_label_for(:application, application.status),
                class: "px-3 py-2 text-sm font-medium rounded-full whitespace-nowrap inline-flex items-center justify-center #{badge_class_for(
                  :application, application.status
                )}")
  end

  def proof_status_badge(_proof_type, status)
    content_tag(:span,
                badge_label_for(:proof, status),
                class: "px-3 py-2 text-sm font-medium rounded-full whitespace-nowrap inline-flex items-center justify-center #{badge_class_for(
                  :proof, status
                )}")
  end

  def evaluation_status_badge(evaluation)
    content_tag(:span,
                badge_label_for(:evaluation, evaluation.status),
                class: "px-3 py-2 text-sm font-medium rounded-full whitespace-nowrap inline-flex items-center justify-center #{badge_class_for(
                  :evaluation, evaluation.status
                )}")
  end

  def training_session_status_badge(session)
    content_tag(:span,
                badge_label_for(:training_session, session.status),
                class: "px-3 py-2 text-sm font-medium rounded-full whitespace-nowrap inline-flex items-center justify-center #{badge_class_for(
                  :training_session, session.status
                )}")
  end

  def medical_certification_status_badge(application)
    content_tag(:span,
                application.medical_certification_status.titleize,
                class: "px-3 py-2 text-sm font-medium rounded-full whitespace-nowrap inline-flex items-center justify-center #{badge_class_for(
                  :certification, application.medical_certification_status
                )}")
  end
end
