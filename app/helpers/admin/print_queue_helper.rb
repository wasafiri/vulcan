module Admin::PrintQueueHelper
  def letter_type_badge_class(letter_type)
    case letter_type.to_s
    when 'account_created'
      'bg-blue-100 text-blue-800'
    when 'registration_confirmation'
      'bg-purple-100 text-purple-800'
    when 'income_proof_rejected', 'residency_proof_rejected' 
      'bg-orange-100 text-orange-800'
    when 'income_threshold_exceeded'
      'bg-red-100 text-red-800'
    when 'application_approved'
      'bg-green-100 text-green-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end
end
