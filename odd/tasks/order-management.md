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

- [ ] Add versioned JSON collection/show/create/full-replacement-update/logical-delete endpoints for restaurants and products.
- [ ] Require Restaurant create `name` and `code`; require Product create `name`, `sku`, and integer `price_clp`. Require every editable PUT field (Restaurant: `name`, `code`, `dispatch_url`, `active`; Product: `name`, `sku`, `price_clp`, `active`); preserve route identity and reject incomplete replacements without mutation.
- [ ] Soft-delete with `deleted_at`; hide deleted resources from collection and show; return 404 for deleted/nonexistent show; treat Restaurant/Product `active` as independent availability, not deletion.
- [ ] Add request tests for success, validation failures/no persistence mutation, full PUT, delete retention/visibility, and JSON responses.
- Route: **delegated direct**. Trigger evidence: controllers/routes/serialization/models/request tests are multiple non-trivial files, and code-reading prepares the write.
- Acceptance: only specified HTTP methods are exposed; PUT fully replaces editable fields; DELETE retains the database row and updates `deleted_at`; deleted rows do not appear in GET; `active: false` alone does not imply deletion.
- Checks: strict TDD; focused API request tests; `bin/rails test`.
- Runtime harness: run Rails against PostgreSQL and exercise representative Restaurant and Product create/read/update/delete requests; record exact command/scenario/result.
- Commit evidence: user-owned; report changed files and verification, but do not commit.
- Status: not started.

### OM-04 — Implement order query/create/logical-delete, price snapshots, and idempotency

- [ ] Add JSON order collection/show/create/logical-delete endpoints only; do not add Order PUT/PATCH or standalone OrderItem routes.
- [ ] Validate required restaurant/customer/type/items data, delivery-only address requirement, product references, quantities, and logical-delete state; persist a complete order and all items atomically.
- [ ] Derive `unit_price_clp`, `subtotal_clp`, and `total_clp` from persisted product prices; ignore client price/total inputs and preserve historical snapshots after product updates/deletion.
- [ ] Implement Idempotency-Key lookup/replay transaction-safely under concurrent requests; existing key returns original order with 200 regardless of payload differences, new order returns 201, and invalid requests persist no partial data.
- [ ] Add request/model tests for pickup and delivery, invalid payload rollback, deleted-resource visibility, snapshots/totals, replay with changed payload, and concurrent same-key calls.
- Route: **delegated direct**. Trigger evidence: multiple controllers/domain operations/migrations/indexes/request tests are non-trivial and related design reading must stay with the writer.
- Acceptance: order routes/method set exactly matches scope; valid create returns 201; replay returns the original order with 200 and no duplicates; one row maximum per key even under concurrency; logical delete sets `deleted_at`, retains order/items, and hides it from GET; product changes never mutate prior snapshots/totals.
- Checks: strict TDD; focused order model/request tests, including concurrency at the supported test database; `bin/rails test`.
- Runtime harness: run Rails/PostgreSQL and exercise new create plus same-key replay; record exact command/scenario/result.
- Commit evidence: user-owned; report changed files and verification, but do not commit.
- Status: not started.

### OM-05 — Close the backend slice with full verification and minimal setup documentation

- [ ] Update setup/API documentation needed to run the PostgreSQL-backed slice locally and describe implemented endpoints/behavior, only after actual behavior is stable.
- [ ] Run final full test/CI checks, resolve regressions within scope, inspect route inventory for forbidden endpoints, and record authored line count/verification evidence.
- Route: **delegated direct**. Trigger evidence: final verification invokes execution tooling and may require coordinated setup/documentation changes; the parent may use a fresh verifier for applicable checks under the delegated verification gate.
- Acceptance: `bin/rails test` and `bin/ci` results are recorded honestly; PostgreSQL migration/setup instructions match actual configuration; no frontend, dispatch workflow, order update, or standalone item endpoint was added; final route inventory matches scope.
- Checks: `bin/rails test`; `bin/ci`; `bin/rails routes` readback for method/path inventory; run the migration from a clean disposable test database where the environment permits.
- Runtime harness: PostgreSQL-backed Rails smoke scenario as above; final API results recorded, or exact environmental limitation reported.
- Commit evidence: user-owned; report changed files and verification, but do not commit.
- Status: not started.

## Progress and Evidence

- Completed exploration: confirmed Rails 8.1.4/Ruby 4.0.7 skeleton, SQLite configuration, empty application route/domain surface, Minitest/fixtures, and configured `bin/ci` checks.
- OM-01 proposal/spec alignment edits are complete and were read back; verified all three resources use `deleted_at`, Restaurant `active` is independent/editable, deleted records are hidden from GET, history is retained, and route/method scope is unchanged. Documentation-only structural check passed; test/runtime harness N/A.
- Repository status before implementation: branch `core/feature/order-module-init` at the same commit as `main`; pre-existing untracked OpenSpec change files must be preserved.
- Completed implementation/check work awaiting user commit: OM-01 documentation only.
- OM-02 implementation verified against local PostgreSQL 14. `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test`: 5 runs, 22 assertions, 0 failures, 0 errors, 0 skips (including parent spot-check). `bin/rails db:create db:migrate RAILS_ENV=test` succeeded; development migration is up.
- Shell default Ruby was 2.6; Rails checks require selecting project Ruby 4.0.7 on `PATH`.
- Pending: OM-03 and OM-04 APIs, OM-05 full checks/docs. Formal native review could not yet scope the candidate cleanly because unrelated existing diagram modification is in the tracked diff and untracked selection was requested; do not absorb or edit the diagram.
- Running authored changed-line count: implementation underway; not yet measured.
- Commits/PRs: user-owned; none created by assistant.
- Native review: not assessed/started; follow the user-owned RDD switch and native candidate lifecycle after each applicable work-unit commit.

## Next Step

Proceed with OM-03 backend code and tests. Do not edit diagrams, commit, push, or open a PR; the user handles delivery actions.

## Document Locator

- Repository-relative: `odd/tasks/order-management.md`
- Absolute: `/Users/amaromontero/Software/niufoods-test/niufoods/odd/tasks/order-management.md`
