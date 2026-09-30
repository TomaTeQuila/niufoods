require "test_helper"

class ApiV1CatalogTest < ActionDispatch::IntegrationTest
  test "restaurants can be listed, shown, created, replaced, and logically deleted" do
    restaurant = Restaurant.create!(name: "Niu", code: "niu")

    get "/api/v1/restaurants", as: :json
    assert_response :success
    assert_equal [restaurant.id], response.parsed_body.map { |record| record.fetch("id") }

    get "/api/v1/restaurants/#{restaurant.id}", as: :json
    assert_response :success
    assert_equal "Niu", response.parsed_body.fetch("name")

    post "/api/v1/restaurants", params: { restaurant: { name: "New", code: "new" } }, as: :json
    assert_response :created
    created_id = response.parsed_body.fetch("id")

    put "/api/v1/restaurants/#{created_id}",
        params: { restaurant: { name: "Changed", code: "changed", dispatch_url: "https://dispatch.test",
                                active: false, id: restaurant.id } }, as: :json
    assert_response :success
    assert_equal "Changed", response.parsed_body.fetch("name")
    assert_equal false, response.parsed_body.fetch("active")
    assert_equal created_id, response.parsed_body.fetch("id")
    get "/api/v1/restaurants/#{created_id}", as: :json
    assert_response :success

    delete "/api/v1/restaurants/#{created_id}", as: :json
    assert_response :no_content
    assert Restaurant.unscoped.find(created_id).deleted_at
    get "/api/v1/restaurants", as: :json
    assert_not_includes response.parsed_body.map { |record| record.fetch("id") }, created_id
    get "/api/v1/restaurants/#{created_id}", as: :json
    assert_response :not_found
  end

  test "restaurant create and replacement reject missing fields without mutation" do
    assert_no_difference "Restaurant.count" do
      post "/api/v1/restaurants", params: { restaurant: { name: "Incomplete" } }, as: :json
    end
    assert_response :unprocessable_entity

    restaurant = Restaurant.create!(name: "Niu", code: "niu")
    assert_no_changes -> { restaurant.reload.attributes } do
      put "/api/v1/restaurants/#{restaurant.id}", params: { restaurant: { name: "Changed", code: "new" } },
          as: :json
    end
    assert_response :unprocessable_entity
  end

  test "products can be listed, shown, created, replaced, and logically deleted" do
    product = Product.create!(name: "Burger", sku: "burger", price_clp: 5_000)

    get "/api/v1/products", as: :json
    assert_response :success
    assert_equal [product.id], response.parsed_body.map { |record| record.fetch("id") }

    get "/api/v1/products/#{product.id}", as: :json
    assert_response :success
    assert_equal 5_000, response.parsed_body.fetch("price_clp")

    post "/api/v1/products", params: { product: { name: "Fries", sku: "fries", price_clp: 2_000 } }, as: :json
    assert_response :created
    created_id = response.parsed_body.fetch("id")

    put "/api/v1/products/#{created_id}",
        params: { product: { name: "Large Fries", sku: "fries-large", price_clp: 3_000, active: false } },
        as: :json
    assert_response :success
    assert_equal 3_000, response.parsed_body.fetch("price_clp")
    assert_equal false, response.parsed_body.fetch("active")

    delete "/api/v1/products/#{created_id}", as: :json
    assert_response :no_content
    assert Product.unscoped.find(created_id).deleted_at
    get "/api/v1/products", as: :json
    assert_not_includes response.parsed_body.map { |record| record.fetch("id") }, created_id
    get "/api/v1/products/#{created_id}", as: :json
    assert_response :not_found
  end

  test "product create and replacement validate fields and integer price" do
    assert_no_difference "Product.count" do
      post "/api/v1/products", params: { product: { name: "Fries", sku: "fries", price_clp: 1.5 } },
          as: :json
    end
    assert_response :unprocessable_entity

    product = Product.create!(name: "Burger", sku: "burger", price_clp: 5_000)
    assert_no_changes -> { product.reload.attributes } do
      put "/api/v1/products/#{product.id}", params: { product: { name: "Fries", sku: "fries", price_clp: 2_000 } },
          as: :json
    end
    assert_response :unprocessable_entity
  end
end
