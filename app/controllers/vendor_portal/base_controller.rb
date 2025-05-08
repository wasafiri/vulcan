# frozen_string_literal: true

module VendorPortal
  # Base controller for all vendor portal controllers
  class BaseController < ApplicationController
    before_action :authenticate_vendor!
    layout 'vendor_portal'

    private

    def authenticate_vendor!
      # First ensure user is authenticated
      authenticate_user!

      # Then verify they are a vendor
      return if current_user&.vendor?

      # Handle format-specific responses for authentication failures
      respond_to do |format|
        format.html do
          flash[:alert] = I18n.t('alerts.must_be_vendor', default: 'You must be a vendor to access this section')
          redirect_to root_path
        end

        format.json do
          render json: { error: 'Unauthorized. Vendor access required.' }, status: :unauthorized
        end

        format.any do
          head :unauthorized
        end
      end
    end
  end
end
