module BadgeHelper
  COLOR_MAPS = {
    proof: {
      not_reviewed: 'bg-gray-100 text-gray-800',
      approved:     'bg-green-100 text-green-800',
      rejected:     'bg-red-100 text-red-800',
      default:      'bg-gray-100 text-gray-800'
    },
    application: {
      draft:              'bg-gray-100 text-gray-800',
      in_progress:        'bg-purple-100 text-purple-800',
      approved:           'bg-green-100 text-green-800',
      rejected:           'bg-red-100 text-red-800',
      needs_information:  'bg-blue-100 text-blue-800',
      reminder_sent:      'bg-purple-100 text-purple-800',
      awaiting_documents: 'bg-orange-100 text-orange-800',
      default:            'bg-gray-100 text-gray-800'
    },
    evaluation: {
      pending:     'bg-yellow-100 text-yellow-800',
      in_progress: 'bg-blue-100 text-blue-800',
      completed:   'bg-green-100 text-green-800',
      default:     'bg-gray-100 text-gray-800'
    },
    training_session: {
      requested:  'bg-yellow-100 text-yellow-800',
      scheduled:  'bg-blue-100 text-blue-800',
      confirmed:  'bg-blue-100 text-blue-800',
      completed:  'bg-green-100 text-green-800',
      cancelled:  'bg-red-100 text-red-800',
      default:    'bg-gray-100 text-gray-800'
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

  def badge_label_for(type, status)
    # Special case for evaluation "pending" status
    return "Requested" if type.to_sym == :evaluation && status.to_s == "pending"
    
    # Handle "confirmed" status as "scheduled"
    return "Scheduled" if type.to_sym == :training_session && status.to_s == "confirmed"
    
    status.to_s.humanize
  end
end
