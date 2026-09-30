class Restaurant < ApplicationRecord
  has_many :orders, inverse_of: :restaurant

  validates :name, :code, presence: true
end
