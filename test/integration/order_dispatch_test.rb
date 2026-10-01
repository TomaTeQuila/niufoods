require "test_helper"
require "sidekiq/testing"

class OrderDispatchTest < ActionDispatch::IntegrationTest
  setup do
    Sidekiq::Testing.fake!
    DispatchOrderJob.clear
    @restaurant = Restaurant.create!(name: "Niu", code: "niu", dispatch_url: "http://example.test/store_api/v1/orders")
    @product = Product.create!(name: "Burger", sku: "burger", price_clp: 5_000)
  end

  test "new order is enqueued once and an idempotency replay is not enqueued again" do
    post "/api/v1/orders", headers: { "Idempotency-Key" => "dispatch-once" }, params: order_payload, as: :json
    assert_response :created
    order_id = response.parsed_body.dig("order", "id")
    assert_equal "pending", response.parsed_body.dig("order", "dispatch_status")
    assert_equal 0, response.parsed_body.dig("order", "dispatch_attempts")
    assert_nil response.parsed_body.dig("order", "last_dispatch_error")
    assert_nil response.parsed_body.dig("order", "dispatched_at")
    assert_equal [order_id], DispatchOrderJob.jobs.map { |job| job.fetch("args").first }

    post "/api/v1/orders", headers: { "Idempotency-Key" => "dispatch-once" }, params: order_payload, as: :json
    assert_response :ok
    assert_equal [order_id], DispatchOrderJob.jobs.map { |job| job.fetch("args").first }
  end

  test "simulated store accepts a dispatch order" do
    post "/store_api/v1/orders", params: { order: { order_number: "ORD-1" } }, as: :json

    assert_response :created
    assert_equal "accepted", response.parsed_body.dig("order", "status")
  end

  test "simulated store rejects malformed order requests" do
    post "/store_api/v1/orders", params: { order: "invalid" }, as: :json

    assert_response :unprocessable_entity
    assert_equal ["order_number is required"], response.parsed_body.fetch("errors")
  end

  private

  def order_payload
    { order: { restaurant_id: @restaurant.id, order_type: "pickup", customer_name: "Ada",
               customer_phone: "555-0100", items: [{ product_id: @product.id, quantity: 2 }] } }
  end
end
