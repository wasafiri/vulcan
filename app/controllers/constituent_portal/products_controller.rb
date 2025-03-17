# app/controllers/constituent_portal/products_controller.rb
class ConstituentPortal::ProductsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_constituent!
  before_action :set_product, only: [ :show ]

  def index
    @products = current_user.products.active.ordered_by_name
  end

  def show; end

  private

  def set_product
    @product = current_user.products.find(params[:id])
  end

  def require_constituent!
    return if current_user&.constituent?

    redirect_to root_path, alert: 'Access denied. Constituent-only area.'
  end
end
