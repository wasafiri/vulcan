# frozen_string_literal: true

module Admin
  class VendorsController < ApplicationController
    before_action :authenticate_user!
    before_action :require_admin!
    before_action :set_vendor, only: %i[show edit update]

    def index
      # Use Users::Vendor to match the STI type column
      @vendors = Users::Vendor.order(:business_name)

      # Filter by W9 status if provided
      return if params[:w9_status].blank?

      @vendors = @vendors.where(w9_status: params[:w9_status])
    end

    def show
      @w9_reviews = @vendor.w9_reviews.includes(:admin).order(created_at: :desc)
    end

    def edit; end

    def update
      if @vendor.update(vendor_params)
        redirect_to admin_vendor_path(@vendor), notice: 'Vendor was successfully updated.'
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_vendor
      # Use Users::Vendor to match the STI type column
      @vendor = Users::Vendor.find(params[:id])
    end

    def vendor_params
      params.expect(vendor: %i[business_name business_tax_id status])
    end

    def require_admin!
      return if current_user&.admin?

      flash[:alert] = 'You are not authorized to perform this action'
      redirect_to root_path
    end
  end
end
