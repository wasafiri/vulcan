# frozen_string_literal: true

module BadgeHelper
  COLOR_MAPS = {
    proof: {
      not_reviewed: 'bg-gray-100 text-gray-800',
      approved: 'bg-green-100 text-green-800',
      rejected: 'bg-red-100 text-red-800',
      default: 'bg-gray-100 text-gray-800'
    },
    certification: {
      not_requested: 'bg-gray-100 text-gray-800',
      requested: 'bg-yellow-100 text-yellow-800',
      received: 'bg-blue-100 text-blue-800',
      approved: 'bg-green-100 text-green-800',
      rejected: 'bg-red-100 text-red-800',
      default: 'bg-gray-100 text-gray-800'
    },
    application: {
      draft: 'bg-gray-100 text-gray-800',
      in_progress: 'bg-purple-100 text-purple-800',
      approved: 'bg-green-100 text-green-800',
      rejected: 'bg-red-100 text-red-800',
      needs_information: 'bg-blue-100 text-blue-800',
      reminder_sent: 'bg-purple-100 text-purple-800',
      awaiting_documents: 'bg-orange-100 text-orange-800',
      default: 'bg-gray-100 text-gray-800'
    },
    evaluation: {
      pending: 'bg-yellow-100 text-yellow-800',
      in_progress: 'bg-blue-100 text-blue-800',
      completed: 'bg-green-100 text-green-800',
      default: 'bg-gray-100 text-gray-800'
    },
    training_session: {
      requested: 'bg-yellow-100 text-yellow-800',
      scheduled: 'bg-blue-100 text-blue-800',
      confirmed: 'bg-blue-100 text-blue-800',
      completed: 'bg-green-100 text-green-800',
      cancelled: 'bg-red-100 text-red-800',
      default: 'bg-gray-100 text-gray-800'
    }
  }.freeze

  def badge_class_for(type, status)
    map_for_type = COLOR_MAPS[type.to_sym] || {}
    css_class = map_for_type[status.to_s.to_sym]
    css_class || map_for_type[:default] || 'bg-gray-100 text-gray-800'
  end

  def proof_status_class(status)
    case status.to_s
    when 'not_reviewed'
      'text-gray-600'
    when 'approved'
      'text-green-600'
    when 'rejected'
      'text-red-600'
    else
      'text-gray-500'
    end
  end

  def certification_status_class(status)
    case status.to_s
    when 'not_requested'
      'text-gray-600'
    when 'requested'
      'text-yellow-600'
    when 'received'
      'text-blue-600'
    when 'approved'
      'text-green-600'
    when 'rejected'
      'text-red-600'
    else
      'text-gray-500'
    end
  end
  
  def medical_certification_label(application)
    status = application.medical_certification_status.to_s
    case status
    when 'not_requested'
      'Medical Certification'
    when 'requested'
      'Medical Certification Request'
    when 'received'
      'Medical Certification Received'
    when 'approved'
      'Medical Certification Approved'
    when 'rejected'
      'Medical Certification Rejected'
    else
      'Medical Certification'
    end
  end
  
  def medical_certification_link(application, style = :link)
    return nil unless application.medical_certification.attached?
    
    url = Rails.application.routes.url_helpers.rails_blob_path(application.medical_certification, disposition: :inline)
    
    if style == :button
      # Use classes similar to other full-height buttons in the form
      link_to 'View Certification', url,
              target: '_blank',
              class: 'inline-flex justify-center py-2 px-4 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500'
    else
      link_to 'View Certification', url,
              target: '_blank',
              class: 'text-blue-600 hover:text-blue-800 underline'
    end
  end
  
  def medical_certification_submission_method(application)
    return 'unknown' unless application.medical_certification.attached?
    
    # Try to find submission method from metadata or related records
    if application.respond_to?(:medical_certification_submission_method) && 
       application.medical_certification_submission_method.present?
      return application.medical_certification_submission_method
    end
    
    # Check for status changes that might have the method
    status_change = ApplicationStatusChange.where(application_id: application.id)
                      .where("metadata->>'change_type' = ? OR to_status = ?", 
                             'medical_certification', 'received')
                      .order(created_at: :desc)
                      .first
    
    if status_change&.metadata.present? && 
       status_change.metadata['submission_method'].present?
      return status_change.metadata['submission_method']
    end
    
    # Default fallback
    'portal'
  end

  def badge_label_for(type, status)
    # Special case for evaluation "pending" status
    return 'Requested' if type.to_sym == :evaluation && status.to_s == 'pending'

    # Handle "confirmed" status as "scheduled"
    return 'Scheduled' if type.to_sym == :training_session && status.to_s == 'confirmed'

    status.to_s.humanize
  end
end
