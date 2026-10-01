require "test_helper"
require_relative "../support/fake_dispatch_server"

class DispatchClientTest < ActiveSupport::TestCase
  setup do
    @restaurant = Restaurant.create!(name: "Niu", code: "niu")
    @product = Product.create!(name: "Burger", sku: "burger", price_clp: 5_000)
    @order = Order.new(restaurant: @restaurant, order_number: "ORD-1", idempotency_key: "client-1",
                       order_type: "pickup", customer_name: "Ada", customer_phone: "555-0100", total_clp: 5_000)
    @order.order_items.build(product: @product, quantity: 1, unit_price_clp: 5_000, subtotal_clp: 5_000)
    @order.save!
  end

  test "classifies successful responses as sent" do
    FakeDispatchServer.new(status: 201).run do |url, server|
      @restaurant.update!(dispatch_url: url)
      assert_equal :sent, DispatchClient.call(@order)
      assert_includes server.request_text, "Idempotency-Key: ORD-1"
      assert_includes server.request_text, '"order_number":"ORD-1"'
    end
  end

  test "classifies server failures as retryable and client failures as definitive" do
    FakeDispatchServer.new(status: 503).run do |url|
      @restaurant.update!(dispatch_url: url)
      result = DispatchClient.call(@order)
      assert_equal :retry, result.status
      assert_match "HTTP 503", result.error
    end

    FakeDispatchServer.new(status: 422).run do |url|
      @restaurant.update!(dispatch_url: url)
      result = DispatchClient.call(@order)
      assert_equal :error, result.status
      assert_match "HTTP 422", result.error
    end
  end

  test "classifies connection timeouts as retryable" do
    @restaurant.update!(dispatch_url: "http://127.0.0.1:1/store_api/v1/orders")
    result = DispatchClient.call(@order)
    assert_equal :retry, result.status
    assert_match(/refused|failed/i, result.error)
  end
end
