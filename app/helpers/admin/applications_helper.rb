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
  end
end
