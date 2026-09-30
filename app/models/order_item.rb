class OrderItem < ApplicationRecord
  belongs_to :order, inverse_of: :order_items
  belongs_to :product, inverse_of: :order_items

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :unit_price_clp, :subtotal_clp, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
