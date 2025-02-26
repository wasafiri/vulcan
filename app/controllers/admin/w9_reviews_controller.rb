class Admin::W9ReviewsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin!
  before_action :set_vendor
  before_action :set_w9_review, only: [ :show ]

  def index
    @w9_reviews = @vendor.w9_reviews.includes(:admin).order(created_at: :desc)
  end

  def show
    @w9_form = @vendor.w9_form

    unless @w9_form&.attached?
      redirect_to admin_vendor_path(@vendor),
        alert: "W9 form no longer available"
    end
  end

  def new
    @w9_review = @vendor.w9_reviews.build

    @w9_form = @vendor.w9_form

    unless @w9_form.attached?
      redirect_to admin_vendor_path(@vendor),
        alert: "W9 form is missing"
    end
  end

  def create
    @w9_review = @vendor.w9_reviews.build(w9_review_params)
    @w9_review.admin = current_user

    if @w9_review.save
      redirect_to admin_vendor_path(@vendor),
        notice: "W9 review completed successfully"
    else
      render :new, status: :unprocessable_entity,
        alert: "W9 review failed to save"
    end
  end

  private

  def set_vendor
    @vendor = Vendor.find(params[:vendor_id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_vendors_path, alert: "Vendor not found"
  end

  def set_w9_review
    @w9_review = @vendor.w9_reviews.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to admin_vendor_path(@vendor), alert: "Review not found"
  end

  def w9_review_params
    params.require(:w9_review).permit(:status, :rejection_reason_code, :rejection_reason)
  end

  def require_admin!
    unless current_user&.admin?
      flash[:alert] = "You are not authorized to perform this action"
      redirect_to root_path
    end
  end
end
