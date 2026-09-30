require "test_helper"

class OrderIdempotencyConcurrencyTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = false

  test "concurrent requests with one key create one order and return the same record" do
    restaurant = Restaurant.create!(name: "Concurrent", code: "concurrent")
    product = Product.create!(name: "Meal", sku: "concurrent-meal", price_clp: 2_500)
    key = "concurrent-#{SecureRandom.uuid}"
    attributes = {
      restaurant_id: restaurant.id,
      order_type: "pickup",
      customer_name: "Ada",
      customer_phone: "555-0100",
      items: [{ product_id: product.id, quantity: 2 }]
    }
    ready = Queue.new
    gate = Queue.new
    threads = 2.times.map do
      Thread.new do
        ActiveRecord::Base.connection_pool.with_connection do
          ready << true
          gate.pop
          OrderCreator.call(idempotency_key: key, attributes:)
        end
      end
    end
    2.times { ready.pop }
    2.times { gate << true }
    results = threads.map(&:value)

    assert_equal 1, Order.where(idempotency_key: key).count
    assert_equal 1, OrderItem.joins(:order).where(orders: { idempotency_key: key }).count
    assert_equal 1, results.map { |result| result.order.id }.uniq.size
  ensure
    threads&.each(&:join)
    if key
      orders = Order.where(idempotency_key: key)
      OrderItem.where(order_id: orders.select(:id)).delete_all
      orders.delete_all
    end
    product&.destroy!
    restaurant&.destroy!
  end
end
