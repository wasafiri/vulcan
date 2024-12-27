require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
 setup do
   @product = products(:one)
   @admin = users(:admin)
   sign_in_as(@admin)
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
   assert_difference("Product.count") do
     post admin_products_path, params: { product: { name: "Test Product" } }
   end
   assert_redirected_to admin_product_path(Product.last)
 end

 test "should get edit" do
   get edit_admin_product_path(@product)
   assert_response :success
 end

 test "should update product" do
   patch admin_product_path(@product), params: { product: { name: "Updated" } }
   assert_redirected_to admin_product_path(@product)
 end

 test "should archive product" do
   patch archive_admin_product_path(@product)
   assert_redirected_to admin_products_path
 end

 test "should unarchive product" do
   patch unarchive_admin_product_path(@product)
   assert_redirected_to admin_products_path
 end
end
