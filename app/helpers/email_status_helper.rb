module EmailStatusHelper
  def delivery_status_badge(notification)
    return "" unless notification.email_tracking?
    
    badge_class = notification.delivery_status_badge_class
    status_text = notification.delivery_status || "Pending"
    
    content_tag(:span, status_text, class: "ml-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium #{badge_class}")
  end
  
  def format_email_status(notification)
    return "" unless notification.email_tracking?
    
    html = []
    
    # Base message
    html << content_tag(:div, class: "mt-2 text-sm") do
      if notification.delivery_status == "error"
        content_tag(:p, class: "text-red-600") do
          "Delivery failed: #{notification.email_error_message}"
        end
      elsif notification.delivered_at.present?
        safe_join([
          content_tag(:p, "Delivered on #{notification.delivered_at.strftime('%B %d, %Y at %I:%M %p')}")
        ])
      else
        content_tag(:p, "Delivery status: Pending")
      end
    end
    
    # Open information if available
    if notification.opened_at.present?
      open_info = []
      open_info << content_tag(:p, "Opened on #{notification.opened_at.strftime('%B %d, %Y at %I:%M %p')}")
      
      # Add client details if available
      if notification.metadata&.dig("email_details", "Client").present?
        client = notification.metadata["email_details"]["Client"]
        open_info << content_tag(:p, "Using #{client['Name']} on #{client['Family']}")
      end
      
      # Add location if available
      if notification.metadata&.dig("email_details", "Geo").present?
        geo = notification.metadata["email_details"]["Geo"]
        if geo["City"].present? && geo["Region"].present?
          open_info << content_tag(:p, "From #{geo['City']}, #{geo['Region']}")
        end
      end
      
      html << content_tag(:div, class: "mt-1 text-sm text-blue-600") do
        safe_join(open_info)
      end
    end
    
    # Manual check button if not delivered and not errored
    if notification.message_id.present? && 
       !notification.delivery_status.in?(["error"]) && 
       notification.opened_at.nil?
      html << content_tag(:div, class: "mt-2") do
        button_to "Check Status", 
                  check_email_status_notification_path(notification),
                  method: :post,
                  class: "text-xs bg-gray-100 hover:bg-gray-200 text-gray-800 font-semibold py-1 px-2 rounded",
                  form: { "data-turbo" => true, class: "inline" }
      end
    end
    
    safe_join(html)
  end
end
