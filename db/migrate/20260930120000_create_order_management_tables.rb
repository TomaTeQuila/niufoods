class CreateOrderManagementTables < ActiveRecord::Migration[8.1]
  def change
    create_table :restaurants do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :dispatch_url
      t.boolean :active, null: false, default: true
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :products do |t|
      t.string :name, null: false
      t.string :sku, null: false
      t.integer :price_clp, null: false
      t.boolean :active, null: false, default: true
      t.datetime :deleted_at
      t.timestamps
    end

    create_table :orders do |t|
      t.string :order_number, null: false
      t.string :idempotency_key, null: false
      t.references :restaurant, null: false, foreign_key: true
      t.string :order_type, null: false
      t.string :customer_name, null: false
      t.string :customer_phone, null: false
      t.string :delivery_address
      t.integer :total_clp, null: false, default: 0
      t.string :dispatch_status, null: false, default: "pending"
      t.integer :dispatch_attempts, null: false, default: 0
      t.text :last_dispatch_error
      t.datetime :dispatched_at
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :orders, :idempotency_key, unique: true

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.integer :unit_price_clp, null: false
      t.integer :subtotal_clp, null: false
      t.timestamps
    end
  end
end
