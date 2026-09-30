# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

restaurants = [
  { id: 1, name: "Niu Foods Providencia", code: "PROV", dispatch_url: nil, active: true, deleted_at: nil },
  { id: 2, name: "Niu Foods Las Condes", code: "LCON", dispatch_url: nil, active: true, deleted_at: nil },
  { id: 3, name: "Niu Foods Ñuñoa", code: "NUNO", dispatch_url: nil, active: true, deleted_at: nil }
].freeze

products = [
  { id: 1, name: "Niu Roll Salmón", sku: "SKU-001", price_clp: 8_990, active: true, deleted_at: nil },
  { id: 2, name: "California Ebi", sku: "SKU-002", price_clp: 7_490, active: true, deleted_at: nil },
  { id: 3, name: "Avocado Roll", sku: "SKU-003", price_clp: 6_990, active: true, deleted_at: nil },
  { id: 4, name: "Nigiri Salmón x2", sku: "SKU-004", price_clp: 3_990, active: true, deleted_at: nil },
  { id: 5, name: "Gyozas de Pollo x5", sku: "SKU-005", price_clp: 4_490, active: true, deleted_at: nil },
  { id: 6, name: "Edamame", sku: "SKU-006", price_clp: 3_290, active: true, deleted_at: nil },
  { id: 7, name: "Bowl Salmón Teriyaki", sku: "SKU-007", price_clp: 9_990, active: true, deleted_at: nil },
  { id: 8, name: "Bowl Pollo Teriyaki", sku: "SKU-008", price_clp: 8_990, active: true, deleted_at: nil },
  { id: 9, name: "Bebida 350 ml", sku: "SKU-009", price_clp: 1_990, active: true, deleted_at: nil },
  { id: 10, name: "Agua Mineral 500 ml", sku: "SKU-010", price_clp: 1_590, active: true, deleted_at: nil }
].freeze

seed_groups = [[Restaurant, :code, restaurants], [Product, :sku, products]]

ApplicationRecord.transaction do
  seed_groups.each do |model, key, entries|
    entries.each do |attributes|
      id_owner = model.find_by(id: attributes.fetch(:id))
      next unless id_owner && id_owner.public_send(key) != attributes.fetch(key)

      raise "Cannot seed #{model.name} #{attributes.fetch(key)} at ID #{attributes.fetch(:id)}: " \
            "that ID belongs to #{key}=#{id_owner.public_send(key)}"
    end
  end

  seed_groups.each do |model, key, entries|
    entries.each do |attributes|
      record = model.find_or_initialize_by(key => attributes.fetch(key))
      record.assign_attributes(record.persisted? ? attributes.except(:id) : attributes)
      record.save!
    end

    ActiveRecord::Base.connection.reset_pk_sequence!(model.table_name)
  end
end
