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
end
