class Vendor::ProfilesController < Vendor::BaseController
  def edit
    @vendor = current_user
  end

  def update
    @vendor = current_user

    if @vendor.update(vendor_params)
      redirect_to vendor_dashboard_path,
        notice: "Profile updated successfully."
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
      :terms_accepted
    ).tap do |permitted_params|
      permitted_params[:terms_accepted_at] = Time.current if permitted_params.delete(:terms_accepted)
    end
  end
end
