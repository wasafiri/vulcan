require "test_helper"

class Admin::ProductsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @admin = users(:admin_david)
    @product = products(:ipad_air)
    sign_in(@admin)
  end

  def test_should_get_index
    get admin_products_path
    assert_response :success
  end

  def test_should_get_new
    get new_admin_product_path
    assert_response :success
  end

  def test_should_create_product
    assert_difference("Product.count") do
      post admin_products_path, params: {
        product: {
          name: "New Test Product",
          manufacturer: "Test Manufacturer",
          model_number: "TEST-001",
          description: "Test Description",
          features: "Test Features",
          compatibility_notes: "Test Notes",
          documentation_url: "https://example.com/docs",
          device_types: [ "Smartphone" ]
        }
      }
    end
    assert_redirected_to admin_products_path
    assert_equal "Product successfully created.", flash[:notice]
  end

  def test_should_show_product
    get admin_product_path(@product)
    assert_response :success
  end

  def test_should_get_edit
    get edit_admin_product_path(@product)
    assert_response :success
  end

  def test_should_update_product
    patch admin_product_path(@product), params: {
      product: {
        name: "Updated iPad Air",
        description: "Updated description"
      }
    }
    assert_redirected_to admin_products_path
    assert_equal "Product successfully updated.", flash[:notice]
    @product.reload
    assert_equal "Updated iPad Air", @product.name
  end

  def test_should_archive_product
    post archive_admin_product_path(@product)
    assert_redirected_to admin_products_path
    @product.reload
    assert_not_nil @product.archived_at
    assert_equal "Product archived.", flash[:notice]
  end

  def test_should_unarchive_product
    @product.update!(archived_at: Time.current)  # Archive first
    post unarchive_admin_product_path(@product)
    assert_redirected_to admin_products_path
    @product.reload
    assert_nil @product.archived_at
    assert_equal "Product unarchived.", flash[:notice]
  end

  def test_should_filter_by_device_type
    get admin_products_path, params: { device_types: [ "Tablet" ] }
    assert_response :success
    assert_select "tr.product-#{products(:ipad_air).id}"
    assert_select "tr.product-#{products(:iphone).id}", count: 0  # Shouldn't show smartphones
  end

  def teardown
    Current.reset
  end
end
