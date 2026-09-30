# Order Management Specification

## Purpose

Define the PostgreSQL-backed JSON API for restaurant and product administration and for creating, querying, and logically deleting orders. This capability includes historical order-item pricing and creation idempotency. It excludes the dashboard, dispatch workflow, simulated-store API, and standalone order-item endpoints.

## Requirements

### Requirement: Persist order-management records and relationships

The system MUST persist restaurants, products, orders, and order items in PostgreSQL with the fields and types shown in `docs/niufoods-db-schema-diagram.pdf` (pages 1–3), plus `deleted_at` timestamp fields for restaurants, products, and orders. Logical deletion of each of those three resource types MUST set `deleted_at` without physically removing the row. Restaurant `active` MUST remain an independent editable status and MUST NOT determine logical deletion or GET visibility. The system MUST preserve rows and historical order data when records are logically deleted.

The schema MUST represent one restaurant to many orders, one order to many order items, and one product to many order items with referential integrity. The `order_type` values MUST be `pickup` and `delivery`; the persisted `dispatch_status` values MUST be `pending`, `sent`, and `error`. Persisting dispatch-related columns does not implement a dispatch workflow.

#### Scenario: Persist an order with related items

- GIVEN a restaurant, products, an order, and order items are stored
- WHEN the order-management records are read from PostgreSQL
- THEN each order references its restaurant
- AND each order item references its order and product
- AND the schema preserves the diagrammed fields and enum values

#### Scenario: Preserve records on logical deletion

- GIVEN a restaurant, product, or order has been logically deleted
- WHEN its database row and associated historical order data are inspected
- THEN the row remains persisted
- AND its `deleted_at` value remains set
- AND deleting a product does not remove historical order items or change their price snapshots
- AND deleting a restaurant does not physically remove its orders

### Requirement: Manage restaurants through the versioned JSON API

The system MUST expose JSON endpoints under `/api/v1/restaurants` for collection and single-resource GET, POST create, PUT update, and DELETE logical destroy. Restaurant creation MUST require `name` and `code`. A restaurant PUT MUST be full replacement: its body MUST contain every editable field (`name`, `code`, `dispatch_url`, and `active`) and MUST NOT use an ID field to select or replace the resource identity. The route ID identifies the resource. DELETE MUST set `deleted_at` without physically removing the row or changing `active`. Restaurant collection GET responses MUST exclude restaurants whose `deleted_at` is set, and show requests for logically deleted or nonexistent restaurants MUST return HTTP 404. Changing `active` through PUT MUST NOT set `deleted_at` or hide the restaurant from GET.

Invalid or incomplete create/update payloads MUST return a client-error response and MUST NOT create or alter persisted restaurant data. Successful API responses MUST be JSON. This specification does not mandate an exact success status code or error-body envelope where the source documentation does not define one.

#### Scenario: Create a restaurant with required fields

- GIVEN a valid JSON request containing `name` and `code`
- WHEN the client posts to `/api/v1/restaurants`
- THEN the restaurant is persisted
- AND the response is a successful JSON response representing the created restaurant

#### Scenario: Reject a restaurant missing a required field

- GIVEN a restaurant create request missing `name` or `code`
- WHEN the client posts to `/api/v1/restaurants`
- THEN the response is a client error
- AND no restaurant is created

#### Scenario: Replace a restaurant using PUT

- GIVEN an existing restaurant
- WHEN the client PUTs all editable fields (`name`, `code`, `dispatch_url`, and `active`) to `/api/v1/restaurants/:id`
- THEN the persisted editable field values are replaced by the request values
- AND the restaurant ID remains unchanged

#### Scenario: Change restaurant active status without deleting it

- GIVEN an undeleted restaurant
- WHEN the client PUTs all editable fields with a changed `active` value
- THEN the `active` value is updated
- AND `deleted_at` remains unset
- AND the restaurant remains visible in collection and show GET responses

#### Scenario: Reject an incomplete restaurant replacement

- GIVEN an existing restaurant
- WHEN the client PUTs a body that omits any editable field
- THEN the response is a client error
- AND the restaurant remains unchanged

#### Scenario: Logically delete a restaurant

- GIVEN an undeleted restaurant with associated orders
- WHEN the client DELETEs `/api/v1/restaurants/:id`
- THEN the restaurant row remains persisted with `deleted_at` set
- AND the `active` status remains unchanged
- AND the restaurant is absent from restaurant collection and show GET responses
- AND associated orders remain persisted

### Requirement: Manage products through the versioned JSON API

The system MUST expose JSON endpoints under `/api/v1/products` for collection and single-resource GET, POST create, PUT update, and DELETE logical destroy. Product creation MUST require `name`, `sku`, and integer `price_clp`. A product PUT MUST be full replacement: its body MUST contain every editable field (`name`, `sku`, and `price_clp`) and MUST NOT use an ID field to select or replace the resource identity. The route ID identifies the resource. DELETE MUST set `deleted_at` without physically removing the row. Product collection GET responses MUST exclude logically deleted products, and show requests for logically deleted or nonexistent products MUST return HTTP 404.

Invalid or incomplete create/update payloads MUST return a client-error response and MUST NOT create or alter persisted product data. Successful API responses MUST be JSON. This specification does not mandate an exact success status code or error-body envelope where the source documentation does not define one.

#### Scenario: Create a product with required fields

- GIVEN a valid JSON request containing `name`, `sku`, and integer `price_clp`
- WHEN the client posts to `/api/v1/products`
- THEN the product is persisted
- AND the response is a successful JSON response representing the created product

#### Scenario: Reject a product missing a required field

- GIVEN a product create request missing `name`, `sku`, or `price_clp`
- WHEN the client posts to `/api/v1/products`
- THEN the response is a client error
- AND no product is created

#### Scenario: Replace a product using PUT

- GIVEN an existing product
- WHEN the client PUTs `name`, `sku`, and `price_clp` to `/api/v1/products/:id`
- THEN the persisted editable field values are replaced by the request values
- AND the product ID remains unchanged

#### Scenario: Reject an incomplete product replacement

- GIVEN an existing product
- WHEN the client PUTs a body that omits any editable field
- THEN the response is a client error
- AND the product remains unchanged

#### Scenario: Logically delete a product without changing order history

- GIVEN a product referenced by an existing order item
- WHEN the client DELETEs `/api/v1/products/:id`
- THEN the product row remains persisted with `deleted_at` set
- AND the product is absent from product collection and show GET responses
- AND the existing order item and its price snapshot remain persisted and unchanged

### Requirement: Create, query, and logically delete orders

The system MUST expose JSON endpoints for `GET /api/v1/orders`, `GET /api/v1/orders/:id`, `POST /api/v1/orders`, and `DELETE /api/v1/orders/:id`. Orders MUST NOT have PUT or PATCH endpoints, and order items MUST NOT have standalone routes. Order creation MUST require `restaurant_id`, `order_type`, `customer_name`, `customer_phone`, and at least one item. Each item MUST reference a product and include a quantity. For `delivery` orders, `delivery_address` MUST be provided; `pickup` orders do not require it. `order_type` MUST be `pickup` or `delivery`.

Creating a valid order MUST persist the order and its items. A new order MUST return HTTP 201. Invalid order payloads MUST return a client-error response and MUST NOT persist a partial order or its items. The order collection GET response MUST exclude orders with `deleted_at` set, and show requests for logically deleted or nonexistent orders MUST return HTTP 404. DELETE MUST set `deleted_at` without physically removing the order or its items. Successful API responses MUST be JSON; response body envelopes not established by the source docs are not prescribed here.

#### Scenario: Create a pickup order

- GIVEN a valid request with `restaurant_id`, `order_type` set to `pickup`, customer name and phone, and at least one item referencing a product with a quantity
- WHEN the client posts to `/api/v1/orders`
- THEN the order and all order items are persisted
- AND the response status is 201
- AND the response represents the created order as JSON

#### Scenario: Create a delivery order with an address

- GIVEN a valid delivery-order request with the required restaurant, customer, and item data and a `delivery_address`
- WHEN the client posts to `/api/v1/orders`
- THEN the order and all order items are persisted
- AND the response status is 201

#### Scenario: Reject a delivery order without an address

- GIVEN a delivery-order request missing `delivery_address`
- WHEN the client posts to `/api/v1/orders`
- THEN the response is a client error
- AND no order or order items are persisted

#### Scenario: Reject an order without required data or items

- GIVEN an order request missing any required restaurant or customer field, using an unsupported order type, or containing no items
- WHEN the client posts to `/api/v1/orders`
- THEN the response is a client error
- AND no order or order items are persisted

#### Scenario: Read an existing order

- GIVEN a persisted order that has not been logically deleted
- WHEN the client requests its collection or show endpoint
- THEN the order is included in the collection or returned by show as JSON

#### Scenario: Logically delete an order

- GIVEN an order with persisted order items
- WHEN the client DELETEs `/api/v1/orders/:id`
- THEN the order row remains persisted with `deleted_at` set
- AND the order and its items are absent from order GET responses
- AND the order items remain persisted

#### Scenario: Do not expose order mutation routes

- GIVEN an order ID
- WHEN a client sends PUT or PATCH to `/api/v1/orders/:id`, or requests a standalone order-item route
- THEN no such application route is exposed

### Requirement: Calculate and preserve historical CLP prices

The system MUST calculate order prices from persisted product `price_clp` values rather than trusting client-submitted totals or unit prices. For each created order item, the system MUST persist `unit_price_clp` as the product price at order creation and `subtotal_clp` as that snapshot multiplied by the item quantity. The order `total_clp` MUST equal the sum of its item subtotals. Product price changes MUST NOT alter existing order-item price snapshots, subtotals, or order totals.

#### Scenario: Calculate totals from stored product prices

- GIVEN an order request containing item product IDs and quantities and products with persisted CLP prices
- WHEN the order is created
- THEN each item's `unit_price_clp` equals its referenced product's stored `price_clp` at creation
- AND each item's `subtotal_clp` equals its unit-price snapshot multiplied by quantity
- AND `total_clp` equals the sum of all item subtotals

#### Scenario: Ignore client-supplied price values when calculating an order

- GIVEN an order request that includes client-supplied totals or unit prices that differ from stored product prices
- WHEN the order is created
- THEN the persisted unit prices, subtotals, and total are calculated from stored product prices and item quantities

#### Scenario: Preserve order snapshots after a product price update

- GIVEN an existing order item with a stored product-price snapshot
- WHEN the referenced product's `price_clp` is changed
- THEN the existing order item's `unit_price_clp` and `subtotal_clp` remain unchanged
- AND the existing order's `total_clp` remains unchanged

### Requirement: Make order creation idempotent

The system MUST use the `Idempotency-Key` header to prevent duplicate order creation, including under concurrent requests. When a key already identifies an order, a repeated POST MUST return the existing order with HTTP 200 rather than creating another order. This follows the documented order sequence, which branches on key existence and returns the existing order without a payload-comparison branch.

#### Scenario: Replay an order creation request

- GIVEN an order was created with an `Idempotency-Key`
- WHEN another POST to `/api/v1/orders` uses the same key
- THEN the existing order is returned with HTTP 200
- AND no second order or duplicate order items are created

#### Scenario: Replay a key with a different payload

- GIVEN an order was created with an `Idempotency-Key`
- WHEN a later POST uses the same key with a different payload
- THEN the existing order is returned with HTTP 200
- AND the different payload does not create or modify an order

#### Scenario: Handle concurrent requests with the same key

- GIVEN multiple concurrent order-create requests use the same `Idempotency-Key`
- WHEN those requests complete
- THEN at most one order is created for that key
- AND the other successful request returns the existing order rather than creating a duplicate

## Scope Exclusions

- The system does not implement order dispatch, Sidekiq/Redis jobs, simulated-store endpoints, dispatch retries, or dispatch-status transitions in this change.
- The system does not implement a React dashboard or other frontend behavior.
- The system does not implement order update endpoints or standalone order-item endpoints.
