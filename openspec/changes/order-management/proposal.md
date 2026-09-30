# Proposal: Core Order Management

## Intent

Provide a testable Rails backend for managing food orders. The repository currently has a Rails skeleton and architecture diagrams, but no order domain, API, or PostgreSQL persistence. This change delivers the core order slice without implementing the documented dispatch or dashboard flows.

## Scope

### In Scope

- Replace the skeleton's SQLite configuration with the latest stable PostgreSQL release and create Rails models and migrations for the documented `restaurants`, `products`, `orders`, and `order_items` tables, including their relationships, constraints, and diagrammed fields. Dispatch-related columns may be persisted as schema, but this change does not operate a dispatch workflow.
- Add versioned JSON CRUD endpoints for restaurants and products: `GET` collection/show, `POST` create, `PUT` update, and `DELETE` logical destroy under `/api/v1/restaurants` and `/api/v1/products`. Logical destroy sets `deleted_at` and preserves records rather than physically removing them. Restaurant `active` is an independent editable status; changing it does not delete or hide the restaurant. Collection/show GET responses hide records whose `deleted_at` is set.
- Add order JSON endpoints: `GET /api/v1/orders`, `GET /api/v1/orders/:id`, `POST /api/v1/orders`, and `DELETE /api/v1/orders/:id`. The DELETE endpoint uses Rails `destroy` action semantics but logically deletes the order by setting `deleted_at`. Orders have no `PUT` or `PATCH` endpoint, and order items have no standalone routes.
- Calculate CLP totals on the server from stored product prices, persist item price snapshots, and prevent duplicate order creation for a repeated `Idempotency-Key` under concurrent requests. Specify mismatched-payload behavior in the API contract.
- Cover model and request behavior with Minitest using RED → GREEN → REFACTOR; verify with `bin/rails test` and the full `bin/ci` check.

### Out of Scope

- React dashboard, UI routes, and frontend setup.
- Redis, Sidekiq, dispatch jobs, simulated-store endpoint, retries, and dispatch-status transitions. Schema compatibility with the database diagram does not imply those behaviors.
- Order update endpoints (`PUT`/`PATCH`), standalone order-item routes, order-generation scripts, or changes to the external store integration.

## Capabilities

### New Capabilities

- `order-management`: PostgreSQL-backed restaurant and product CRUD plus order create, list, read, and logical-delete API behavior, including pricing snapshots and creation idempotency; no order update or standalone order-item API.

### Modified Capabilities

None. `openspec/specs/` contains no existing capability specification to modify.

## Approach

Build the vertical Rails order slice first: configure PostgreSQL, express the database diagram as migrations and model relationships, then implement conventional restaurant and product CRUD routes alongside order GET/POST/DELETE routes. Use `deleted_at` for logical deletion of restaurants, products, and orders; keep restaurant `active` independent from deletion. Hide deleted records from collection/show GET while preserving rows and historical order items. Keep money in integer CLP units; derive `unit_price_clp`, item `subtotal_clp`, and order `total_clp` on the server rather than trusting client totals. Use a database uniqueness constraint and transaction-safe request handling for `Idempotency-Key`, not only a model validation. Specify and test the API contract, including restaurant/product PUT semantics and visibility of logically deleted resources, before writing behavior. Do not add comments to application code.

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `Gemfile`, `config/database.yml` | Modified | PostgreSQL adapter and environment configuration. |
| `db/migrate/`, `db/schema.rb` or PostgreSQL structure dump | New/Modified | Documented tables, fields, relationships, indexes, and constraints. |
| `app/models/` | New | Restaurant, product, order, and order-item domain models. |
| `config/routes.rb`, `app/controllers/api/v1/` | New/Modified | Versioned restaurant/product CRUD and order GET/POST/DELETE APIs; no standalone order-item routes. |
| `test/models/`, `test/integration/` | New | Pricing, persistence, validation, idempotency, and endpoint coverage. |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Product updates could overwrite historical order prices. | Medium | Keep order-item price snapshots immutable and totals server-derived; test that product updates do not alter existing order history. |
| Logical deletion could expose deleted resources or leave relationships inconsistent. | Medium | Set `deleted_at` without deleting rows, hide deleted resources from GET, preserve related historical records, and test the contract. |
| Concurrent retries could create duplicate orders. | Medium | Enforce idempotency in PostgreSQL and test concurrent/same-key cases. |
| SQLite-to-PostgreSQL migration could disrupt local data or CI. | Medium | Validate connection/setup and full CI; back up any non-disposable data before migration. |
| Dispatch columns in the diagram could be mistaken for an implemented workflow. | Low | Keep dispatch behavior explicitly outside this change and avoid worker/store routes. |

## Rollback Plan

Revert the restaurant, product, and order APIs, models, migrations, and PostgreSQL configuration as one change. In disposable environments, recreate the prior development/test databases. For any non-disposable database, take a backup before deployment and use a reviewed restoration plan rather than assuming a destructive down-migration is safe; do not remove order data until its retention needs are resolved.

## Dependencies

- Available PostgreSQL service and credentials for development, test, and CI.
- Logical deletion and update semantics are specified: Restaurant and Product PUT are full replacements of their editable fields; all three resource types use `deleted_at`, deleted records are hidden from GET, and historical rows are retained. Restaurant `active` is independent status and does not control deletion or GET visibility.
- The supplied docs and spec intentionally do not prescribe exact success status codes or error-body envelopes for Restaurant and Product endpoints; keep successful responses JSON and invalid-request responses in the client-error class without inventing a more specific contract.

## Success Criteria

- [ ] PostgreSQL migrations reproduce the four documented tables and relationships, and the Rails app boots and tests against PostgreSQL.
- [ ] Restaurant and product list, read, create, update, and delete endpoints satisfy the request/response contract and reject invalid requests predictably; DELETE sets `deleted_at` without physically deleting the record, and GET hides deleted records.
- [ ] Order list, read, create, and delete endpoints satisfy the request/response contract and reject invalid requests predictably; DELETE sets `deleted_at` without physically deleting the order, GET hides deleted orders, and no order update or standalone order-item endpoint exists.
- [ ] Server-calculated CLP totals and stored item price snapshots remain correct after order creation and subsequent product updates.
- [ ] Repeated or concurrent requests with one idempotency key do not create duplicate orders.
- [ ] Relevant model and integration tests pass under strict TDD, followed by `bin/rails test` and `bin/ci`.
- [ ] No frontend, dispatch worker, simulated-store route, order update endpoint, or standalone order-item route is introduced.
