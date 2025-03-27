# frozen_string_literal: true

module VendorPortal
  # Base controller for all vendor portal controllers
  class BaseController < ApplicationController
    before_action :authenticate_vendor!
    layout 'vendor_portal'

    private

    def authenticate_vendor!
      authenticate_user!
      return if current_user&.vendor?

      flash[:alert] = I18n.t('alerts.must_be_vendor', default: 'You must be a vendor to access this section')
      redirect_to root_path
    end
  end
end
