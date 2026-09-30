# Order Management — ODD Feature Tasks

## Objective

Deliver the approved PostgreSQL-backed Rails order-management API: restaurant and product administration, order creation/query/logical deletion, server-calculated CLP totals and immutable item price snapshots, and transaction-safe `Idempotency-Key` replay.

## Problem and Why

The Rails repository is currently a skeleton: it has no PostgreSQL application schema, domain models, API routes, or meaningful tests, and `config/database.yml` still points at SQLite. The user authorized implementing the defined backend slice and selected ODD instead of continuing the SDD pipeline. The tracking document records bounded implementation work and observed verification. The user owns commits and pull requests; do not commit, push, or open PRs.

## Scope and Constraints

### In scope

- PostgreSQL persistence and Rails models/migrations for `restaurants`, `products`, `orders`, and `order_items`, with diagrammed fields and referential integrity.
- JSON endpoints under `/api/v1`: Restaurant and Product collection/show GET, POST, full-replacement PUT, and logical DELETE; Order collection/show GET, POST, and logical DELETE.
- Restaurant, Product, and Order logical deletion all use `deleted_at`; `active` is an independent availability status for existing Restaurant/Product records, can be changed by full PUT, and does not imply deletion. All deleted records are hidden from collection/show GET. Preserve rows and historical order items. Do not edit diagrams; the user owns diagram changes.
- Order create requires `restaurant_id`, `order_type`, customer name/phone, and at least one item (product and quantity); `delivery_address` is required only for delivery. Order types are `pickup` and `delivery`.
- Calculate CLP totals from persisted product prices, snapshot item unit price/subtotal at creation, and keep historical prices/totals stable after product price changes.
- Idempotency-key order creation replay returns the existing order with HTTP 200; a new order returns HTTP 201. Database-level uniqueness/transaction handling must prevent duplicate rows during concurrent same-key requests. Same-key different-payload replay returns the original order without mutation.
- Cover models and requests with Minitest using strict RED → GREEN → REFACTOR.

### Out of scope

- Frontend/dashboard, React setup, dispatch workflow, Redis/Sidekiq, workers/retries, simulated-store endpoints, dispatch status transitions, order update endpoints, standalone order-item routes, and order-generation scripts.
- Any change to the external store integration.

### Constraints and evidence

- Preserve existing untracked OpenSpec files; align their text as an explicit documentation task rather than treating them as implementation authority.
- Do not add application-code comments.
- Current branch is `core/feature/order-module-init`, already feature-named and at the same commit as `main`/`origin/main` (`5f82c54`); no branch change is needed before implementation.
- Existing `config/ci.rb` defines `bin/ci` as setup, RuboCop, bundler-audit, importmap audit, Brakeman, `bin/rails test`, and test seed replant.
- The schema diagram defines fields and relationships but not nullability, defaults, uniqueness/index details. Implement only constraints justified by the approved contract and relational integrity; document the chosen minimal persistence constraints in migrations/tests.

## TDD and Verification Configuration

- `strict_tdd: true`
- Source: project initialization record `sdd-init/niufoods` and repository test configuration.
- Framework/runner: Rails Minitest; exact focused/full test command `bin/rails test` (focused paths may be used during a task).
- Workspace check: `bin/ci`.
- Strict sequence for every behavior task: demonstrate a failing test first, implement until green, then refactor with tests still green. Record the observed RED/GREEN/REFACTOR evidence; do not infer it.

## Delivery Forecast and Strategy

- Forecast: approximately **800–1,150 authored changed lines** across documentation, migrations/configuration, models, controllers, and request/model tests; generated schema output is excluded from the authored count. This is an early estimate because the repository has no existing application conventions to reuse.
- Delivery: user-owned. Assistant makes code changes and records verification only; user handles commits, PR strategy, and pull request creation. No chain-strategy question or commits by assistant.

## Actionable Tasks

### OM-01 — Align written order-management contract with latest deletion decision

- [ ] Update the existing proposal and capability spec to say Restaurant, Product, and Order logical deletion use `deleted_at`; make Restaurant `active` independent and editable, and specify all deleted records are hidden from collection/show GET. Preserve historical rows/order items and existing API route limits.
- Route: **delegated direct**. Trigger evidence: two non-trivial existing documents require reading and consistent edits; writer must load the task document and `cognitive-doc-design` skill before editing.
- Acceptance: the proposal/spec no longer conflict with the latest user decision; neither expands frontend/dispatch scope nor adds order PUT/PATCH or standalone item routes; both edited docs read back consistently.
- Checks: structural readback of both documents; no test/runtime harness applies to a passive documentation-only change (record `N/A`, reason: no executable boundary).
- Commit evidence: not applicable; user owns commits. Keep proposal/spec as references and do not edit diagrams.
- Status: content and structural verification complete; no assistant commit required.

### OM-02 — Establish PostgreSQL schema and order-management domain models

- [ ] Replace SQLite application database configuration/dependency with PostgreSQL for development, test, and production; preserve required Rails auxiliary database behavior only if compatible with the current deployment setup.
- [ ] Add migrations for diagrammed restaurant/product/order/order-item fields, `active` availability flags for Restaurant/Product distinct from `deleted_at` on all three logical-deletion resources, foreign keys, and the uniqueness needed for idempotency; add model associations and validations for core persisted values.
- [ ] Add model/schema tests for relationships, enum domains, soft-delete fields, and idempotency uniqueness; verify historical references survive logical deletion.
- Route: **delegated direct**. Trigger evidence: the task reads before writing and changes multiple non-trivial files across Gemfile/lock, database config, migrations, models, and tests.
- Acceptance: a fresh PostgreSQL database can migrate; Rails models persist all four records and relationships; order type is `pickup|delivery`, persisted dispatch status is `pending|sent|error` without implementing dispatch; deleted rows remain stored; uniqueness is enforced at the database boundary for idempotency keys.
- Checks: strict TDD; focused new model tests, `bin/rails db:migrate` against PostgreSQL, `bin/rails test`. Record any unavailable PostgreSQL service as blocked/partial rather than substituting SQLite.
- Runtime harness: Rails database setup/migration against PostgreSQL; capture exact command/result.
- Commit evidence: user-owned; report changed files and verification, but do not commit.
- Status: complete (uncommitted; user owns commit/PR). Added PostgreSQL persistence, domain models and focused model tests. RED: tests failed before missing models existed. GREEN: 5 tests / 21 assertions passed after implementation. REFACTOR: database unique-index assertion added; focused suite passed 5 tests / 22 assertions. PostgreSQL test DB created/migrated successfully; development DB migration is up.

### OM-03 — Implement Restaurant and Product JSON APIs

- [x] Add versioned JSON collection/show/create/full-replacement-update/logical-delete endpoints for restaurants and products.
- [x] Require Restaurant create `name` and `code`; require Product create `name`, `sku`, and integer `price_clp`. Require every editable PUT field (Restaurant: `name`, `code`, `dispatch_url`, `active`; Product: `name`, `sku`, `price_clp`, `active`); preserve route identity and reject incomplete replacements without mutation.
- [x] Soft-delete with `deleted_at`; hide deleted resources from collection and show; return 404 for deleted/nonexistent show; treat Restaurant/Product `active` as independent availability, not deletion.
- [x] Add request tests for success, validation failures/no persistence mutation, full PUT, delete retention/visibility, and JSON responses.
- Route: **delegated direct**. Trigger evidence: controllers/routes/serialization/models/request tests are multiple non-trivial files, and code-reading prepares the write.
- Acceptance: only specified HTTP methods are exposed; PUT fully replaces editable fields; DELETE retains the database row and updates `deleted_at`; deleted rows do not appear in GET; `active: false` alone does not imply deletion.
- Checks: strict TDD; focused API request tests; `bin/rails test`.
- Runtime harness: run Rails against PostgreSQL and exercise representative Restaurant and Product create/read/update/delete requests; record exact command/scenario/result.
- Commit evidence: user-owned; report changed files and verification, but do not commit.
- Status: complete (uncommitted; user owns commit/PR). Strict TDD: RED: the focused request tests failed (4 runs, 8 assertions, 4 failures) because the API routes did not exist. GREEN: after adding the API implementation, the focused suite passed (4 runs, 38 assertions); expanded cases for route identity, inactive-but-not-deleted resources, and JSON numeric price validation passed (4 runs, 40 assertions). REFACTOR: replacement and response field sets were centralized as controller constants; focused suite remained green (4 runs, 40 assertions). Full suite passed (9 runs, 62 assertions). PostgreSQL smoke evidence: `bin/rails runner -e test 'puts ActiveRecord::Base.connection.adapter_name'` reported `PostgreSQL`; focused integration request tests exercised Restaurant and Product create/read/update/delete against that test database. Route inventory confirms only GET/POST/PUT/DELETE for these resources, with no PATCH.

### OM-04 — Implement order query/create/logical-delete, price snapshots, and idempotency

- [x] Add JSON order collection/show/create/logical-delete endpoints only; do not add Order PUT/PATCH or standalone OrderItem routes.
- [x] Validate required restaurant/customer/type/items data, delivery-only address requirement, product references, quantities, and logical-delete state; persist a complete order and all items atomically.
- [x] Derive `unit_price_clp`, `subtotal_clp`, and `total_clp` from persisted product prices; ignore client price/total inputs and preserve historical snapshots after product updates/deletion.
- [x] Implement Idempotency-Key lookup/replay transaction-safely under concurrent requests; existing key returns original order with 200 regardless of payload differences, new order returns 201, and invalid requests persist no partial data.
- [x] Add request/model tests for pickup and delivery, invalid payload rollback, deleted-resource visibility, snapshots/totals, replay with changed payload, and concurrent same-key calls.
- Route: **delegated direct**. Trigger evidence: multiple controllers/domain operations/migrations/indexes/request tests are non-trivial and related design reading must stay with the writer.
- Acceptance: order routes/method set exactly matches scope; valid create returns 201; replay returns the original order with 200 and no duplicates; one row maximum per key even under concurrency; logical delete sets `deleted_at`, retains order/items, and hides it from GET; product changes never mutate prior snapshots/totals.
- Checks: strict TDD; focused order model/request tests, including concurrency at the supported test database; `bin/rails test`.
- Runtime harness: run Rails/PostgreSQL and exercise new create plus same-key replay; record exact command/scenario/result.
- Commit evidence: user-owned; report changed files and verification, but do not commit.
- Status: complete (uncommitted; user owns commit/PR). Added order JSON collection/show/create/logical-delete endpoints, transaction-safe creation with database-unique idempotency replay, server-derived totals/item snapshots, and request/concurrency coverage. API response shape is `{ "order": { ... } }` for create/show and `{ "orders": [...] }` for collection; invalid create is 422 with `errors` array; delete is 204. RED: focused requests initially returned 404 because routes/controllers were absent (6 tests, 4 failures/2 expected HTML parse errors). GREEN: focused order request/concurrency tests passed 8 runs/30 assertions. REFACTOR: complete suite passed 13 runs/52 assertions; route inventory confirmed only GET/POST collection and GET/DELETE show. Assumption: `active: false` means unavailable for new orders, while `deleted_at` independently hides deleted records; inactive/deleted restaurants/products are rejected for order creation. Idempotency replay is looked up before payload validation and returns the original order even for changed input.

### OM-05 — Close the backend slice with full verification and minimal setup documentation

- [ ] Update setup/API documentation needed to run the PostgreSQL-backed slice locally and describe implemented endpoints/behavior, only after actual behavior is stable.
- [ ] Run final full test/CI checks, resolve regressions within scope, inspect route inventory for forbidden endpoints, and record authored line count/verification evidence.
- Route: **delegated direct**. Trigger evidence: final verification invokes execution tooling and may require coordinated setup/documentation changes; the parent may use a fresh verifier for applicable checks under the delegated verification gate.
- Acceptance: `bin/rails test` and `bin/ci` results are recorded honestly; PostgreSQL migration/setup instructions match actual configuration; no frontend, dispatch workflow, order update, or standalone item endpoint was added; final route inventory matches scope.
- Checks: `bin/rails test`; `bin/ci`; `bin/rails routes` readback for method/path inventory; run the migration from a clean disposable test database where the environment permits.
- Runtime harness: PostgreSQL-backed Rails smoke scenario as above; final API results recorded, or exact environmental limitation reported.
- Commit evidence: user-owned; report changed files and verification, but do not commit.
- Status: not started.

### OM-06 — Seed the supplied restaurant and product catalog

- [x] Add idempotent, convergent Rails seeds for the three supplied Restaurants and ten supplied Products, keyed by `code` and `sku`; set supplied IDs only when available without overwriting unrelated records, and ensure the PostgreSQL ID sequences remain valid.
- [x] Add focused Minitest coverage proving initial creation and rerun convergence, including `active: true` and `deleted_at: nil` for matching master records.
- [x] Inspect the local development database before mutation; stop if any requested explicit ID belongs to a different record. Preserve unrelated rows and seed only the development database with `bin/rails db:seed`.
- Route: **delegated direct**. Trigger evidence: behavior and focused test require coordinated changes to seed code and tests; project test execution is delegated.
- Acceptance: all supplied field values and safe requested IDs are present; repeated seed runs converge without duplicate keyed records or changing unrelated records; test and development environments remain distinct.
- Checks: strict TDD; focused seeds test RED/GREEN/REFACTOR; full `bin/rails test`; inspect existing development rows before `bin/rails db:seed`, then query back exact rows/IDs.
- Commit evidence: user-owned; do not commit, push, or open a PR.
- Status: complete (uncommitted; user owns commit/PR). RED: focused seeds test failed (1 run, 1 assertion) because seed loading created no catalog rows. GREEN: focused suite passed (2 runs, 17 assertions); full test suite passed (11 runs, 79 assertions). Development database was empty before seeding; `bin/rails db:seed` created the requested 3 restaurants and 10 products in `niufoods_development`; exact readback passed, with ID sequences at 3 and 10. Collision behavior and rerun convergence are covered by the focused test.

## Progress and Evidence

- Completed exploration: confirmed Rails 8.1.4/Ruby 4.0.7 skeleton, SQLite configuration, empty application route/domain surface, Minitest/fixtures, and configured `bin/ci` checks.
- OM-01 proposal/spec alignment edits are complete and were read back; verified all three resources use `deleted_at`, Restaurant `active` is independent/editable, deleted records are hidden from GET, history is retained, and route/method scope is unchanged. Documentation-only structural check passed; test/runtime harness N/A.
- Repository status before implementation: branch `core/feature/order-module-init` at the same commit as `main`; pre-existing untracked OpenSpec change files must be preserved.
- Completed implementation/check work awaiting user commit: OM-01 documentation only.
- OM-02 implementation verified against local PostgreSQL 14. `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test`: 5 runs, 22 assertions, 0 failures, 0 errors, 0 skips (including parent spot-check). `bin/rails db:create db:migrate RAILS_ENV=test` succeeded; development migration is up.
- Shell default Ruby was 2.6; Rails checks require selecting project Ruby 4.0.7 on `PATH`.
- OM-04 implementation: `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test`: 13 runs, 52 assertions, 0 failures, 0 errors, 0 skips. Focused request/concurrency suite: 8 runs, 30 assertions, 0 failures, 0 errors, 0 skips. `bin/rails routes` confirms only GET/POST `/api/v1/orders`, GET/DELETE `/api/v1/orders/:id`; no order PUT/PATCH or standalone order-item routes. No manual running-server Postman smoke was performed.
- OM-04 Postman example: `POST http://localhost:3000/api/v1/orders`, header `Content-Type: application/json`, header `Idempotency-Key: postman-order-001`, body `{"order":{"restaurant_id":1,"order_type":"delivery","customer_name":"Ada Lovelace","customer_phone":"+56912345678","delivery_address":"Av. Providencia 123","items":[{"product_id":1,"quantity":2}],"total_clp":1,"price_clp":1}}`. Client totals/prices are ignored; response carries persisted totals and snapshots.
- OM-03 API implementation and request verification are complete; OM-04 APIs and OM-06 catalog seeding are also complete; pending OM-05 full checks/docs. Formal native review could not yet scope the candidate cleanly because unrelated existing diagram modification is in the tracked diff and untracked selection was requested; do not absorb or edit the diagram.
- OM-03 changed files: `config/routes.rb`, `app/controllers/api/v1/restaurants_controller.rb`, `app/controllers/api/v1/products_controller.rb`, `test/integration/api_v1_catalog_test.rb`. `git diff --check` passed; generated log/cache changes from test runs were discarded.
- OM-06 added `db/seeds.rb` and `test/integration/seeds_test.rb`. Focused seeds verification: 2 runs, 17 assertions, 0 failures/errors/skips; full `bin/rails test`: 11 runs, 79 assertions, 0 failures/errors/skips. Development DB inspection before mutation showed no Restaurants or Products; `bin/rails db:seed` targeted `niufoods_development` and completed; exact readback verified supplied IDs, names, codes/SKUs, integer CLP prices, `active=true`, `deleted_at=nil`, and nil Restaurant `dispatch_url`. PostgreSQL sequences read back at 3 (restaurants) and 10 (products); no test seed replant ran.
- Commits/PRs: user-owned; none created by assistant.
- Native review: not assessed/started; follow the user-owned RDD switch and native candidate lifecycle after each applicable work-unit commit.

## Next Step

Proceed with OM-05 final verification/documentation. Do not edit diagrams, commit, push, or open a PR; the user handles delivery actions.

## Document Locator

- Repository-relative: `odd/tasks/order-management.md`
- Absolute: `/Users/amaromontero/Software/niufoods-test/niufoods/odd/tasks/order-management.md`
