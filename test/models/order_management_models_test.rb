require "test_helper"

class OrderManagementModelsTest < ActiveSupport::TestCase
  test "restaurant availability and logical deletion are independent" do
    restaurant = Restaurant.new(name: "Niu", code: "niu", active: false)

    assert restaurant.valid?
    assert_not restaurant.active
    assert_nil restaurant.deleted_at
  end

  test "product availability and logical deletion are independent" do
    product = Product.new(name: "Burger", sku: "burger", price_clp: 5_000, active: false)

    assert product.valid?
    assert_not product.active
    assert_nil product.deleted_at
  end

  test "order and item associations preserve records across logical deletion" do
    restaurant = Restaurant.create!(name: "Niu", code: "niu")
    product = Product.create!(name: "Burger", sku: "burger", price_clp: 5_000)
    order = Order.new(restaurant: restaurant, order_number: "O-1", idempotency_key: "key-1",
                      order_type: "pickup", customer_name: "Ada", customer_phone: "123",
                      total_clp: 5_000, dispatch_status: "pending")
    order.order_items.build(product: product, quantity: 1, unit_price_clp: 5_000, subtotal_clp: 5_000)
    order.save!
    item = order.order_items.first

    assert_equal [order], restaurant.orders
    assert_equal [item], order.order_items
    assert_equal [item], product.order_items
    restaurant.update!(deleted_at: Time.current)
    product.update!(deleted_at: Time.current)

    assert_equal 1, Restaurant.unscoped.count
    assert_equal 1, Product.unscoped.count
    assert_equal product, order.order_items.first.product
  end

  test "order enums reject values outside the persisted domains" do
    order = Order.new(order_number: "O-1", idempotency_key: "key-1", order_type: "dine_in",
                      customer_name: "Ada", customer_phone: "123", total_clp: 0,
                      dispatch_status: "pending")

    assert_not order.valid?
    assert_includes order.errors.attribute_names, :order_type

    order.order_type = "pickup"
    order.dispatch_status = "queued"
    assert_not order.valid?
    assert_includes order.errors.attribute_names, :dispatch_status
  end

  test "idempotency keys are unique in validation and database" do
    Restaurant.create!(name: "Niu", code: "niu")
    product = Product.create!(name: "Burger", sku: "burger", price_clp: 5_000)
    attributes = { restaurant: Restaurant.first, order_number: "O-1", idempotency_key: "key-1",
                   order_type: "pickup", customer_name: "Ada", customer_phone: "123",
                   total_clp: 0, dispatch_status: "pending" }
    order = Order.new(attributes)
    order.order_items.build(product:, quantity: 1, unit_price_clp: 5_000, subtotal_clp: 5_000)
    order.save!
    duplicate = Order.new(attributes.merge(order_number: "O-2"))

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :idempotency_key
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end
end
