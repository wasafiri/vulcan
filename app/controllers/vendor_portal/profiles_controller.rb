# frozen_string_literal: true

module VendorPortal
  class ProfilesController < VendorPortal::BaseController
    def edit
      @vendor = current_user
    end

    def update
      @vendor = current_user

      # Check if a new W9 form is being uploaded
      w9_form_changed = params.dig(:vendor, :w9_form).present?

      if @vendor.update(vendor_params)
        # If W9 form was updated, set status to pending_review
        @vendor.update(w9_status: :pending_review) if w9_form_changed

        redirect_to vendor_dashboard_path,
                    notice: 'Profile updated successfully.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def vendor_params
      params.require(:vendor).permit(
        :business_name,
        :business_tax_id,
        :w9_form,
        :terms_accepted,
        :website_url
      ).tap do |permitted_params|
        permitted_params[:terms_accepted_at] = Time.current if permitted_params.delete(:terms_accepted)
      end
    end
  end
end
