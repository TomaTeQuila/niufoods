class OrderCreator
  Result = Struct.new(:order, :replayed, keyword_init: true)

  def self.call(idempotency_key:, attributes:)
    new(idempotency_key:, attributes:).call
  end

  def initialize(idempotency_key:, attributes:)
    @idempotency_key = idempotency_key
    @attributes = attributes
  end

  def call
    existing = Order.find_by(idempotency_key: @idempotency_key)
    return Result.new(order: existing, replayed: true) if existing

    order = build_order
    order.valid?
    order.errors.add(:restaurant, "must exist and be active") if @missing_restaurant
    order.errors.add(:order_items, "must reference existing, non-deleted products") if @missing_product
    return Result.new(order:, replayed: false) if order.errors.any?

    Order.transaction { order.save! }
    Result.new(order:, replayed: false)
  rescue ActiveRecord::RecordNotUnique
    existing = Order.find_by!(idempotency_key: @idempotency_key)
    Result.new(order: existing, replayed: true)
  rescue ActiveRecord::RecordInvalid => error
    Result.new(order: error.record, replayed: false)
  end

  private

  def build_order
    restaurant = Restaurant.find_by(id: @attributes[:restaurant_id], deleted_at: nil, active: true)
    order = Order.new(
      restaurant:,
      order_number: SecureRandom.uuid,
      idempotency_key: @idempotency_key,
      order_type: @attributes[:order_type],
      customer_name: @attributes[:customer_name],
      customer_phone: @attributes[:customer_phone],
      delivery_address: @attributes[:delivery_address],
      dispatch_status: "pending"
    )

    unless restaurant
      @missing_restaurant = true
      return order
    end

    item_attributes.each do |item|
      product = Product.find_by(id: item[:product_id], deleted_at: nil, active: true)
      unless product
        @missing_product = true
        next
      end

      quantity = item[:quantity]
      order.order_items.build(product:, quantity:, unit_price_clp: product.price_clp,
                              subtotal_clp: product.price_clp * quantity.to_i)
    end
    order.total_clp = order.order_items.sum(&:subtotal_clp)
    order
  end

  def item_attributes
    items = @attributes[:items]
    return [] unless items.is_a?(Array)

    items.filter_map do |item|
      next unless item.respond_to?(:[])

      item = item.with_indifferent_access
      { product_id: item[:product_id], quantity: item[:quantity] }
    end
  end
end
