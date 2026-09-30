class Product < ApplicationRecord
  has_many :order_items, inverse_of: :product

  validates :name, :sku, presence: true
  validates :price_clp, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
