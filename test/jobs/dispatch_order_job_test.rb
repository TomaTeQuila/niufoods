require "test_helper"
require_relative "../support/fake_dispatch_server"

class DispatchOrderJobTest < ActiveSupport::TestCase
  setup do
    @restaurant = Restaurant.create!(name: "Niu", code: "niu", dispatch_url: "http://example.test/store_api/v1/orders")
    @product = Product.create!(name: "Burger", sku: "burger", price_clp: 5_000)
    @order = Order.new(restaurant: @restaurant, order_number: "ORD-1", idempotency_key: "dispatch-job-1",
                       order_type: "pickup", customer_name: "Ada", customer_phone: "555-0100", total_clp: 5_000)
    @order.order_items.build(product: @product, quantity: 1, unit_price_clp: 5_000, subtotal_clp: 5_000)
    @order.save!
  end

  test "successful dispatch records sent status, attempt count, and timestamp" do
    with_dispatch_server(201) do
      DispatchOrderJob.new.perform(@order.id)
    end

    @order.reload
    assert_equal "sent", @order.dispatch_status
    assert_equal 1, @order.dispatch_attempts
    assert_not_nil @order.dispatched_at
    assert_nil @order.last_dispatch_error
  end

  test "definitive dispatch failure records terminal error without retrying" do
    with_dispatch_server(422) do
      DispatchOrderJob.new.perform(@order.id)
    end

    @order.reload
    assert_equal "error", @order.dispatch_status
    assert_equal 1, @order.dispatch_attempts
    assert_match "HTTP 422", @order.last_dispatch_error
    assert_nil @order.dispatched_at
  end

  test "temporary dispatch failure is raised for Sidekiq retry" do
    with_dispatch_server(503) do
      assert_raises(DispatchClient::RetryableError) { DispatchOrderJob.new.perform(@order.id) }
    end

    @order.reload
    assert_equal "pending", @order.dispatch_status
    assert_equal 1, @order.dispatch_attempts
    assert_match "HTTP 503", @order.last_dispatch_error
  end

  test "Sidekiq retry succeeds on a later attempt and clears the prior error" do
    with_dispatch_server(503) do
      assert_raises(DispatchClient::RetryableError) { DispatchOrderJob.new.perform(@order.id) }
    end

    with_dispatch_server(201) { DispatchOrderJob.new.perform(@order.id) }

    @order.reload
    assert_equal "sent", @order.dispatch_status
    assert_equal 2, @order.dispatch_attempts
    assert_nil @order.last_dispatch_error
    assert_not_nil @order.dispatched_at
    assert_equal 5, DispatchOrderJob.get_sidekiq_options.fetch("retry")
  end

  test "retry exhaustion records a terminal error" do
    DispatchOrderJob.sidekiq_retries_exhausted_block.call(
      { "args" => [@order.id] }, DispatchClient::RetryableError.new("HTTP 503: unavailable after retries")
    )

    @order.reload
    assert_equal "error", @order.dispatch_status
    assert_equal "HTTP 503: unavailable after retries", @order.last_dispatch_error
    assert_nil @order.dispatched_at
  end

  private

  def with_dispatch_server(status, &block)
    FakeDispatchServer.new(status:).run do |url|
      @restaurant.update!(dispatch_url: url)
      block.call
    end
  end
end
