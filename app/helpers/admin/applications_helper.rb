# frozen_string_literal: true

module Admin
  module ApplicationsHelper
    def toggle_direction(column)
      if params[:sort] == column
        params[:direction] == 'asc' ? 'desc' : 'asc'
      else
        'asc'
      end
    end

    def certification_status_class(status)
      case status
      when 'requested' then 'bg-yellow-100 text-yellow-800'
      when 'received' then 'bg-blue-100 text-blue-800'
      when 'accepted', 'approved' then 'bg-green-100 text-green-800'
      when 'rejected' then 'bg-red-100 text-red-800'
      else 'bg-gray-100 text-gray-800'
      end
    end
    
    # Determines the submission method for a medical certification from status changes
    # @param application [Application] The application to check
    # @return [String] The submission method (fax, email, portal, etc.) or nil if not found
    def medical_certification_submission_method(application)
      return nil unless application.medical_certification.attached?
      
      # Find the relevant status change with method information
      status_change = ApplicationStatusChange.where(application_id: application.id)
                      .where("metadata->>'change_type' = ? OR metadata->>'submission_method' IS NOT NULL", 'medical_certification')
                      .order(created_at: :desc)
                      .first
      
      return 'fax' unless status_change # Default to fax for legacy data
      
      method = status_change.try(:metadata).try(:[], 'submission_method') || 
               status_change.try(:metadata).try(:fetch, 'submission_method', nil)
               
      method.presence || 'fax' # Default to fax if method is blank
    end
    
    # Returns a user-friendly label for a medical certification based on submission method
    # @param application [Application] The application with the certification
    # @return [String] A descriptive label
    def medical_certification_label(application)
      method = medical_certification_submission_method(application)
      
      case method
      when 'fax'    then 'Faxed Certification'
      when 'email'  then 'Emailed Certification'
      when 'portal' then 'Portal-uploaded Certification'
      when 'mail'   then 'Mailed Certification'
      else 'Uploaded Certification'
      end
    end

    # Displays a medical certification link/button in different styles
    # @param application [Application] The application with the medical certification
    # @param style [Symbol] :link (simple text link) or :button (full button)
    # @param options [Hash] Additional options for customization
    # @return [String] HTML for the link or nil if no certification attached
    def medical_certification_link(application, style = :link, _options = {})
      return unless application.medical_certification.attached?

      link_path = rails_blob_path(application.medical_certification, disposition: :inline)

      # Common attributes
      attrs = {
        target: '_blank',
        rel: 'noopener noreferrer',
        data: { turbo: false }
      }

      case style
      when :link
        # Simple link with icon
        content_tag(:div, class: "flex items-center space-x-3") do
          content_tag(:div, class: "flex-shrink-0") do
            tag.svg(class: "h-5 w-5 text-gray-400", xmlns: "http://www.w3.org/2000/svg", viewBox: "0 0 20 20", fill: "currentColor") do
              tag.path(fill_rule: "evenodd", d: "M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4zm2 6a1 1 0 011-1h6a1 1 0 110 2H7a1 1 0 01-1-1zm1 3a1 1 0 100 2h6a1 1 0 100-2H7z", clip_rule: "evenodd")
            end
          end +
          link_to("View Medical Certification", link_path, 
                  class: "text-sm font-medium text-indigo-600 hover:text-indigo-500", 
                  **attrs)
        end
      when :button
        # Green button with icon
        link_to(link_path, class: "inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-green-600 hover:bg-green-700 focus:outline-none", **attrs) do
          content_tag(:svg, class: "h-5 w-5 mr-2", xmlns: "http://www.w3.org/2000/svg", fill: "none", viewBox: "0 0 24 24", stroke: "currentColor") do
            content_tag(:path, nil, stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M15 12a3 3 0 11-6 0 3 3 0 016 0z") +
            content_tag(:path, nil, stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z")
          end + "View Certification"
        end
      end
    end
  end
end
