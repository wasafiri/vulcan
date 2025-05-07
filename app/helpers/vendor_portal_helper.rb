# frozen_string_literal: true

module VendorPortalHelper
  def invoice_status_badge_class(status)
    case status.to_s.downcase # Ensure consistent string comparison
    when 'pending', 'submitted'
      'bg-yellow-100 text-yellow-800'
    when 'paid', 'approved'
      'bg-green-100 text-green-800'
    when 'rejected', 'cancelled', 'void'
      'bg-red-100 text-red-800'
    when 'processing'
      'bg-blue-100 text-blue-800'
    else
      'bg-gray-100 text-gray-800' # Default for unknown statuses
    end
  end
end
