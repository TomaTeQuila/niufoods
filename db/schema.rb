# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 20_260_930_120_000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension 'pg_catalog.plpgsql'

  create_table 'order_items', force: :cascade do |t|
    t.bigint 'order_id', null: false
    t.bigint 'product_id', null: false
    t.integer 'quantity', null: false
    t.integer 'unit_price_clp', null: false
    t.integer 'subtotal_clp', null: false
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['order_id'], name: 'index_order_items_on_order_id'
    t.index ['product_id'], name: 'index_order_items_on_product_id'
  end

  create_table 'orders', force: :cascade do |t|
    t.string 'order_number', null: false
    t.string 'idempotency_key', null: false
    t.bigint 'restaurant_id', null: false
    t.string 'order_type', null: false
    t.string 'customer_name', null: false
    t.string 'customer_phone', null: false
    t.string 'delivery_address'
    t.integer 'total_clp', default: 0, null: false
    t.string 'dispatch_status', default: 'pending', null: false
    t.integer 'dispatch_attempts', default: 0, null: false
    t.text 'last_dispatch_error'
    t.datetime 'dispatched_at'
    t.datetime 'deleted_at'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.index ['idempotency_key'], name: 'index_orders_on_idempotency_key', unique: true
    t.index ['restaurant_id'], name: 'index_orders_on_restaurant_id'
  end

  create_table 'products', force: :cascade do |t|
    t.string 'name', null: false
    t.string 'sku', null: false
    t.integer 'price_clp', null: false
    t.boolean 'active', default: true, null: false
    t.datetime 'deleted_at'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  create_table 'restaurants', force: :cascade do |t|
    t.string 'name', null: false
    t.string 'code', null: false
    t.string 'dispatch_url'
    t.boolean 'active', default: true, null: false
    t.datetime 'deleted_at'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
  end

  add_foreign_key 'order_items', 'orders'
  add_foreign_key 'order_items', 'products'
  add_foreign_key 'orders', 'restaurants'
end
