require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  RESTAURANTS = [
    [1, "Niu Foods Providencia", "PROV"],
    [2, "Niu Foods Las Condes", "LCON"],
    [3, "Niu Foods Ñuñoa", "NUNO"]
  ].freeze

  PRODUCTS = [
    [1, "Niu Roll Salmón", "SKU-001", 8_990],
    [2, "California Ebi", "SKU-002", 7_490],
    [3, "Avocado Roll", "SKU-003", 6_990],
    [4, "Nigiri Salmón x2", "SKU-004", 3_990],
    [5, "Gyozas de Pollo x5", "SKU-005", 4_490],
    [6, "Edamame", "SKU-006", 3_290],
    [7, "Bowl Salmón Teriyaki", "SKU-007", 9_990],
    [8, "Bowl Pollo Teriyaki", "SKU-008", 8_990],
    [9, "Bebida 350 ml", "SKU-009", 1_990],
    [10, "Agua Mineral 500 ml", "SKU-010", 1_590]
  ].freeze

  test "seeds create the supplied catalog and converge matching records on rerun" do
    Rails.application.load_seed

    assert_equal RESTAURANTS, Restaurant.order(:id).pluck(:id, :name, :code)
    assert_equal PRODUCTS, Product.order(:id).pluck(:id, :name, :sku, :price_clp)
    assert_equal [[true, nil, nil]] * 3, Restaurant.order(:id).pluck(:active, :deleted_at, :dispatch_url)
    assert_equal [[true, nil]] * 10, Product.order(:id).pluck(:active, :deleted_at)

    Restaurant.find(1).update!(name: "Changed", active: false, deleted_at: Time.current)
    Product.find(1).update!(name: "Changed", price_clp: 1, active: false, deleted_at: Time.current)
    unrelated_restaurant = Restaurant.create!(name: "Other Restaurant", code: "OTHER")
    unrelated_product = Product.create!(name: "Other Product", sku: "OTHER", price_clp: 1)

    Rails.application.load_seed

    assert_equal RESTAURANTS, Restaurant.where(id: 1..3).order(:id).pluck(:id, :name, :code)
    assert_equal PRODUCTS, Product.where(id: 1..10).order(:id).pluck(:id, :name, :sku, :price_clp)
    assert_equal [[true, nil, nil]] * 3, Restaurant.where(id: 1..3).order(:id).pluck(:active, :deleted_at, :dispatch_url)
    assert_equal [[true, nil]] * 10, Product.where(id: 1..10).order(:id).pluck(:active, :deleted_at)
    assert Restaurant.exists?(unrelated_restaurant.id)
    assert Product.exists?(unrelated_product.id)
  end

  test "seeds refuse an occupied supplied ID without partial changes" do
    existing = Restaurant.create!(id: 1, name: "Existing", code: "OTHER")

    error = assert_raises(RuntimeError) { Rails.application.load_seed }

    assert_includes error.message, "ID 1: that ID belongs to code=OTHER"
    assert_equal "Existing", existing.reload.name
    assert_empty Product.all
    assert_equal [existing.id], Restaurant.pluck(:id)
  end
end
