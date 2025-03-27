# frozen_string_literal: true

module VendorPortal
  # Controller for vendor profile management
  class ProfilesController < BaseController
    def edit
      @vendor = current_user
    end

    def update
      @vendor = current_user

      if @vendor.update(vendor_params)
        flash[:notice] = 'Profile updated successfully'
        redirect_to vendor_dashboard_path
      else
        flash.now[:alert] = 'There was an error updating your profile'
        render :edit
      end
    end

    private

    def vendor_params
      params.require(:user).permit(
        :name,
        :company_name,
        :address_line1,
        :address_line2,
        :city,
        :state,
        :zip_code,
        :phone,
        :fax,
        :email,
        :website_url
      )
    end
  end
end
