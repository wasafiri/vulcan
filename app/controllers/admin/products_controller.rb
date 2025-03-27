# frozen_string_literal: true

module Admin
  class ProductsController < ApplicationController
    before_action :require_admin!
    before_action :set_product, only: %i[show edit update archive unarchive]
    include Pagy::Backend

    def index
      scope = Product.includes(:vendors).ordered_by_name
      if params[:device_types].present?
        types = Array(params[:device_types]).select(&:present?)
        scope = scope.with_selected_types(types) if types.any?
      end

      @products = params[:show_archived] ? scope : scope.active
      @pagy, @products = pagy(@products, items: 20)

      @products_by_type = @products.each_with_object({}) do |product, hash|
        (product.device_types || []).each do |type|
          hash[type] ||= []
          hash[type] << product
        end
      end
    end

    def show; end

    def new
      @product = Product.new
      load_vendors
    end

    def create
      @product = Product.new(product_params)
      if @product.save
        redirect_to admin_products_path, notice: 'Product successfully created.'
      else
        load_vendors
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      load_vendors
    end

    def update
      if @product.update(product_params)
        redirect_to admin_products_path, notice: 'Product successfully updated.'
      else
        load_vendors
        render :edit, status: :unprocessable_entity
      end
    end

    def archive
      if @product&.archive!
        redirect_to admin_products_path, notice: 'Product archived.'
      else
        redirect_to admin_products_path, alert: 'Could not archive product.'
      end
    end

    def unarchive
      if @product&.unarchive!
        redirect_to admin_products_path, notice: 'Product unarchived.'
      else
        redirect_to admin_products_path, alert: 'Could not unarchive product.'
      end
    end

    private

    def product_params
      filtered_params = params.require(:product).permit(
        :name,
        :manufacturer,
        :model_number,
        :description,
        :features,
        :compatibility_notes,
        :documentation_url,
        device_types: [],
        vendor_ids: []
      )
      filtered_params[:device_types]&.reject!(&:blank?)
      filtered_params
    end

    def set_product
      @product = Product.find_by(id: params[:id])
      return if @product

      redirect_to admin_products_path, alert: 'Product not found.'
    end

    def load_vendors
      @vendors = User.vendors.ordered_by_name
    end
  end
end
