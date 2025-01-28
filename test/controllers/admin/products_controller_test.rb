# test/controllers/admin/products_controller_test.rb

require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = create(:admin)
    sign_in(@admin)
    @product = create(:product)
  end

  test "should get index" do
    get admin_products_path
    assert_response :success
  end

  test "should get show" do
    get admin_product_path(@product)
    assert_response :success
  end

  test "should get new" do
    get new_admin_product_path
    assert_response :success
  end

  test "should create product" do
    assert_difference("Product.count", 1) do
      post admin_products_path, params: { product: {
        name: "Test Product",
        price: 19.99,               # Add required fields
        description: "A new product"
      } }
    end
    assert_redirected_to admin_product_path(Product.last)
  end

  test "should get edit" do
    get edit_admin_product_path(@product)
    assert_response :success
  end

  test "should update product" do
    patch admin_product_path(@product), params: { product: { name: "Updated Product" } }
    assert_redirected_to admin_product_path(@product)
  end

  test "should archive product" do
    post archive_admin_product_path(@product) # Use POST as per routes
    assert_redirected_to admin_products_path
  end

  test "should unarchive product" do
    post unarchive_admin_product_path(@product) # Use POST as per routes
    assert_redirected_to admin_products_path
  end
end
