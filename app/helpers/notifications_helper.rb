# frozen_string_literal: true

module NotificationsHelper
  def delivery_status_badge_class(notification)
    return 'bg-gray-100 text-gray-600' unless notification.email_tracking?

    case notification.delivery_status
    when 'delivered' then 'bg-green-100 text-green-800'
    when 'opened'    then 'bg-blue-100 text-blue-800'
    when 'error'     then 'bg-red-100 text-red-800'
    else 'bg-yellow-100 text-yellow-800'
    end
  end
end
