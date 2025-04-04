# frozen_string_literal: true

module ConstituentPortal
  # Helper methods for activity display in the constituent portal
  module ActivityHelper
    # Returns the CSS class for an activity icon
    def activity_icon_class(activity)
      base_classes = "h-8 w-8 rounded-full flex items-center justify-center ring-8 ring-white"
      
      case activity.activity_type
      when :submission, :resubmission
        "#{base_classes} text-blue-600"
      when :approval
        "#{base_classes} text-green-600"
      when :rejection
        "#{base_classes} text-red-600"
      else
        "#{base_classes} text-gray-500"
      end
    end
  end
end
