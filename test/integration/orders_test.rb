require "test_helper"

class OrdersTest < ActionDispatch::IntegrationTest
  setup do
    @restaurant = Restaurant.create!(name: "Niu", code: "niu")
    @product = Product.create!(name: "Burger", sku: "burger", price_clp: 5_000)
  end

  test "creates an order using persisted prices and returns a JSON resource" do
    post "/api/v1/orders", headers: { "Idempotency-Key" => "order-1" }, params: order_payload,
         as: :json

    assert_response :created
    json = response.parsed_body
    assert_equal "pickup", json.dig("order", "order_type")
    assert_equal 10_000, json.dig("order", "total_clp")
    assert_equal 5_000, json.dig("order", "order_items", 0, "unit_price_clp")
    assert_equal 10_000, json.dig("order", "order_items", 0, "subtotal_clp")
  end

  test "requires a delivery address only for delivery" do
    post "/api/v1/orders", headers: { "Idempotency-Key" => "delivery-1" },
         params: order_payload(order_type: "delivery"), as: :json

    assert_response :unprocessable_entity
    assert_equal 0, Order.count

    post "/api/v1/orders", headers: { "Idempotency-Key" => "delivery-2" },
         params: order_payload(order_type: "delivery", delivery_address: "1 Main St"), as: :json
    assert_response :created
  end

  test "rejects invalid references and quantities without partial writes" do
    payload = order_payload(items: [{ product_id: @product.id, quantity: 0 }])
    post "/api/v1/orders", headers: { "Idempotency-Key" => "invalid-1" }, params: payload, as: :json
    assert_response :unprocessable_entity
    assert_equal [0, 0], [Order.count, OrderItem.count]
  end

  test "replays idempotency key with original order despite changed payload" do
    post "/api/v1/orders", headers: { "Idempotency-Key" => "replay-1" }, params: order_payload, as: :json
    original_id = response.parsed_body.dig("order", "id")
    @product.update!(price_clp: 9_000)
    post "/api/v1/orders", headers: { "Idempotency-Key" => "replay-1" },
         params: order_payload(customer_name: "Changed", items: [{ product_id: @product.id, quantity: 3 }]),
         as: :json

    assert_response :ok
    assert_equal original_id, response.parsed_body.dig("order", "id")
    assert_equal "Ada", response.parsed_body.dig("order", "customer_name")
    assert_equal 1, Order.count
  end

  test "snapshots survive product changes and deleted orders are hidden but retained" do
    post "/api/v1/orders", headers: { "Idempotency-Key" => "snapshot-1" }, params: order_payload, as: :json
    id = response.parsed_body.dig("order", "id")
    @product.update!(price_clp: 10_000)
    assert_equal 5_000, OrderItem.first.unit_price_clp
    assert_equal 10_000, Order.first.total_clp

    delete "/api/v1/orders/#{id}"
    assert_response :no_content
    assert_equal 1, OrderItem.count
    get "/api/v1/orders/#{id}"
    assert_response :not_found
    get "/api/v1/orders"
    assert_equal [], response.parsed_body.fetch("orders")
  end

  test "requires idempotency key and an existing non-deleted restaurant and product" do
    post "/api/v1/orders", params: order_payload, as: :json
    assert_response :unprocessable_entity
    assert_equal 0, Order.count

    @product.update!(deleted_at: Time.current)
    post "/api/v1/orders", headers: { "Idempotency-Key" => "deleted-product" },
         params: order_payload, as: :json
    assert_response :unprocessable_entity
    assert_equal 0, Order.count
  end

  test "rejects inactive restaurants and products without treating them as deleted" do
    @product.update!(active: false)
    post "/api/v1/orders", headers: { "Idempotency-Key" => "inactive-product" }, params: order_payload, as: :json
    assert_response :unprocessable_entity
    assert_equal 0, Order.count
    assert_nil @product.reload.deleted_at
  end

  private

  def order_payload(order_type: "pickup", delivery_address: nil, customer_name: "Ada", items: nil)
    {
      order: {
        restaurant_id: @restaurant.id,
        order_type: order_type,
        customer_name: customer_name,
        customer_phone: "555-0100",
        delivery_address: delivery_address,
        items: items || [{ product_id: @product.id, quantity: 2 }],
        total_clp: 1,
        price_clp: 1
      }
    }
  end
end
