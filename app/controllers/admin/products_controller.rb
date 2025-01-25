class Admin::ProductsController < ApplicationController
  before_action :require_admin!
  before_action :set_product, only: [ :show, :edit, :update, :archive, :unarchive ]

  def index
    @products = Product.order(:manufacturer, :name)

    if params[:device_types].present?
      selected_types = Array(params[:device_types])
      @products = @products.where("device_types::text[] && ?::text[]", "{#{selected_types.join(',')}}")
    end

    @products = params[:show_archived] ? @products : @products.active
    @products_by_type = @products.each_with_object({}) do |product, hash|
      product.device_types.each do |type|
        hash[type] ||= []
        hash[type] << product
      end
    end
  end

  def show
  end

  def new
    Rails.logger.debug "Creating new product"
    @product = Product.new
    Rails.logger.debug "Product: #{@product.inspect}"
    render "new"
  end

  def create
    @product = Product.new(product_params)

    if @product.save
      redirect_to admin_products_path, notice: "Product successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @product.update(product_params)
      redirect_to admin_products_path, notice: "Product successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def archive
    @product.archive!
    redirect_to admin_products_path, notice: "Product archived."
  end

  def unarchive
    @product.unarchive!
    redirect_to admin_products_path, notice: "Product unarchived."
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def product_params
    params.require(:product).permit(:name, :manufacturer, :model_number, device_types: [])
  end
end
