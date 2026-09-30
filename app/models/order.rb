class Order < ApplicationRecord
  ORDER_TYPES = %w[pickup delivery].freeze
  DISPATCH_STATUSES = %w[pending sent error].freeze

  belongs_to :restaurant, inverse_of: :orders
  has_many :order_items, inverse_of: :order

  validates :order_number, :idempotency_key, :customer_name, :customer_phone, presence: true
  validates :order_type, inclusion: { in: ORDER_TYPES }
  validates :dispatch_status, inclusion: { in: DISPATCH_STATUSES }
  validates :total_clp, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :idempotency_key, uniqueness: true
  validates :delivery_address, presence: true, if: :delivery_order?
  validate :must_have_order_items

  private

  def delivery_order?
    order_type == "delivery"
  end

  def must_have_order_items
    errors.add(:order_items, "must contain at least one item") if order_items.empty?
  end
end
