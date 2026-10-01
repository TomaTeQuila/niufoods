# Order Management — ODD Feature Tasks

## Objective

Deliver the PostgreSQL-backed Rails order-management application: restaurant and product administration, order creation/query/logical deletion, server-calculated CLP totals and immutable item price snapshots, transaction-safe `Idempotency-Key` replay, and the Spanish-language, Niu Foods/Niu Sushi-branded React operational dashboard.

## Problem and Why

The Rails repository began as a skeleton and is being extended into the test's order-management application. The user has now explicitly expanded the earlier backend-only scope to include a React dashboard matching the technical test. The tracking document records bounded implementation work and observed verification. The user owns commits and pull requests; do not commit, push, or open PRs.

## Scope and Constraints

### In scope

- PostgreSQL persistence and Rails models/migrations for `restaurants`, `products`, `orders`, and `order_items`, with diagrammed fields and referential integrity.
- JSON endpoints under `/api/v1`: Restaurant and Product collection/show GET, POST, full-replacement PUT, and logical DELETE; Order collection/show GET, POST, and logical DELETE.
- Restaurant, Product, and Order logical deletion all use `deleted_at`; `active` is an independent availability status for existing Restaurant/Product records, can be changed by full PUT, and does not imply deletion. All deleted records are hidden from collection/show GET. Preserve rows and historical order items. Do not edit diagrams; the user owns diagram changes.
- Order create requires `restaurant_id`, `order_type`, customer name/phone, and at least one item (product and quantity); `delivery_address` is required only for delivery. Order types are `pickup` and `delivery`.
- Calculate CLP totals from persisted product prices, snapshot item unit price/subtotal at creation, and keep historical prices/totals stable after product price changes.
- Idempotency-key order creation replay returns the existing order with HTTP 200; a new order returns HTTP 201. Database-level uniqueness/transaction handling must prevent duplicate rows during concurrent same-key requests. Same-key different-payload replay returns the original order without mutation.
- Cover models and requests with Minitest using strict RED → GREEN → REFACTOR.
- Add a React dashboard at the Rails root that reads the existing order and restaurant JSON APIs, displays the operational fields required by the test, uses Niu Foods/Niu Sushi branding and Spanish UI, and includes the requested inert search field.

### Out of scope

- Order update endpoints, standalone order-item routes, and order-generation scripts.
- Any change to the external store integration beyond the locally simulated endpoint defined by the dispatch sequence diagram.

### Constraints and evidence

- Preserve existing untracked OpenSpec files; align their text as an explicit documentation task rather than treating them as implementation authority.
- Do not add application-code comments.
- Current OM-07 working branch is `ui/feature/new-react-dashboard`; prior backend work was performed on `core/feature/order-module-init`. Do not create commits or alter diagrams; delivery remains user-owned.
- Existing `config/ci.rb` defines `bin/ci` as setup, RuboCop, bundler-audit, importmap audit, Brakeman, `bin/rails test`, and test seed replant.
- The schema diagram defines fields and relationships but not nullability, defaults, uniqueness/index details. Implement only constraints justified by the approved contract and relational integrity; document the chosen minimal persistence constraints in migrations/tests.

## TDD and Verification Configuration

- `strict_tdd: true`
- Source: project initialization record `sdd-init/niufoods` and repository test configuration.
- Framework/runner: Rails Minitest; exact focused/full test command `bin/rails test` (focused paths may be used during a task).
- Workspace check: `bin/ci`.
- Strict sequence for every behavior task: demonstrate a failing test first, implement until green, then refactor with tests still green. Record the observed RED/GREEN/REFACTOR evidence; do not infer it.

## Delivery Forecast and Strategy

- Forecast: approximately **1,400–2,000 authored changed lines** across backend and the React dashboard; generated schema/build output is excluded from the authored count. This is an early estimate because the repository has no existing application conventions to reuse.
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
- Status: complete including scoped Postman/CSRF compatibility (uncommitted; user owns commit/PR). Added order JSON collection/show/create/logical-delete endpoints, transaction-safe creation with database-unique idempotency replay, server-derived totals/item snapshots, and request/concurrency coverage. API response shape is `{ "order": { ... } }` for create/show and `{ "orders": [...] }` for collection; invalid create is 422 with `errors` array; delete is 204. RED: focused requests initially returned 404 because routes/controllers were absent (6 tests, 4 failures/2 expected HTML parse errors). GREEN: focused order request/concurrency tests passed 8 runs/30 assertions. REFACTOR: complete suite passed 13 runs/52 assertions; route inventory confirmed only GET/POST collection and GET/DELETE show. Assumption: `active: false` means unavailable for new orders, while `deleted_at` independently hides deleted records; inactive/deleted restaurants/products are rejected for order creation. Idempotency replay is looked up before payload validation and returns the original order even for changed input. CSRF follow-up complete: user-provided log showed `ActionController::InvalidAuthenticityToken` for JSON `POST /api/v1/orders`; `skip_forgery_protection` is scoped to `Api::V1::OrdersController` only. This stateless API does not use browser cookie/session authentication, so Postman needs no browser token; web controllers retain inherited CSRF protection. No global forgery setting changed.

### OM-05 — Close the backend slice with full verification and minimal setup documentation

- [ ] Update setup/API documentation needed to run the PostgreSQL-backed slice locally and describe implemented endpoints/behavior, only after actual behavior is stable.
- [ ] Run final full test/CI checks, resolve regressions within scope, inspect route inventory for forbidden endpoints, and record authored line count/verification evidence.
- Route: **delegated direct**. Trigger evidence: final verification invokes execution tooling and may require coordinated setup/documentation changes; the parent may use a fresh verifier for applicable checks under the delegated verification gate.
- Acceptance: `bin/rails test` and `bin/ci` results are recorded honestly; PostgreSQL migration/setup instructions match actual configuration; no frontend, dispatch workflow, order update, or standalone item endpoint was added; final route inventory matches scope.
- Checks: `bin/rails test`; `bin/ci`; `bin/rails routes` readback for method/path inventory; run the migration from a clean disposable test database where the environment permits.
- Runtime harness: PostgreSQL-backed Rails smoke scenario as above; final API results recorded, or exact environmental limitation reported.
- Commit evidence: user-owned; report changed files and verification, but do not commit.
- Status: not started.

### OM-10 — Implement Redis-backed Sidekiq order dispatch

- [x] Reconcile the current runtime with the architecture and sequence diagrams: Redis queue, Sidekiq worker, dispatch module, simulated-store endpoint, and dispatch status transitions; preserve the existing PostgreSQL order schema and `pending|sent|error` state model.
- [x] Enqueue dispatch only for a newly committed order; ensure idempotency replays do not enqueue duplicates and jobs cannot run before the order transaction commits.
- [x] Implement the simulated-store HTTP endpoint and dispatch client from diagram requirements. Classify transient transport/server failures for Sidekiq retries and definitive responses as terminal `error`; record attempts/error details and successful `dispatched_at` consistently with the schema.
- [x] Replace Solid Queue with Sidekiq as the configured Active Job adapter, configure Redis URL/connection, provide a local Redis + web + worker run path, and remove stale Solid Queue runtime configuration only where safe.
- [x] Add focused job, dispatch-client, API, retry/status and idempotency tests; document how to run and observe the worker and how to exercise dispatch locally.
- Route: **delegated direct**. Trigger evidence: implementation spans dependencies/lockfile, Rails job/service/client/controllers/configuration, runtime services, tests and documentation; diagram/source reading prepares the change.
- Acceptance: a newly created order is persisted and queued once, the Sidekiq worker processes the job through the simulated store, success updates dispatch metadata, retryable errors are retried, terminal failures become `error`, and same-key replays do not create extra work. Redis/Sidekiq are observable in the local run path, and the app no longer starts Solid Queue.
- Constraints: follow `docs/niufoods-architecture-diagram.pdf`, `docs/niufoods-sequence-diagram.png`, `docs/niufoods-db-schema-diagram.pdf`, and `docs/README.md`; do not edit diagrams. Keep API/web authentication behavior unchanged, do not implement a real external store integration, and do not commit/push/open a PR (user owns delivery).
- TDD/verification: `strict_tdd: true`; runner `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test`; demonstrate RED before implementation, GREEN, then REFACTOR. Verify focused tests and full Rails suite; exercise Redis/Sidekiq runtime if local services are available and report any unavailable integration check honestly.
- Forecast: roughly 700–1,100 authored changed lines including focused tests/config/docs; revisit after implementation if the diagram reveals additional contract scope.
- Status: implementation and functional verification complete (uncommitted; user owns delivery). Strict-TDD RED: before source implementation, focused tests failed as expected (5 runs, 1 assertion, 1 missing simulated-store route failure, 4 missing job/client constant errors). GREEN/refactor: focused dispatch suite passed 11 runs / 49 assertions; full `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test` passed 32 runs / 169 assertions, zero failures/errors/skips. Parent spot-check: `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test test/integration/order_dispatch_test.rb` passed 3 runs / 12 assertions. `bundle check`, `git diff --check`, route inventory, and `docker compose config --quiet` passed. Runtime smoke: local PostgreSQL test DB + Redis + Rails server + Sidekiq worker processed a newly created order through `POST /store_api/v1/orders`; API returned 201, then showed `sent`, 1 attempt, dispatch timestamp, no error. Same-key replay returned 200 and Redis processed count remained 1. Temporary smoke records were deleted and local Redis/server/worker stopped. Docker Compose images were not pulled or started; Compose syntax was validated only. `bin/ci` was not run because its dependency audits can contact non-RubyGems hosts outside the authorized network scope. Sidekiq 7.3.9 initially selected `connection_pool` 3.0.2, whose keyword-only `pop` broke Sidekiq's scheduled poller; pinned `connection_pool ~> 2.5` (resolved 2.5.5) and verified clean worker startup. Assumption: HTTP 5xx, 408/425/429, and transport/timeouts are retryable; other non-2xx responses are terminal. The dispatch client sends a stable `Idempotency-Key` derived from `order_number` to support at-least-once worker delivery. Native review is pending: selectorless STATUS required the provider capture `external.select_intended_untracked`, which is unavailable in this session; no native approval/receipt is claimed.

### OM-06 — Seed the supplied restaurant and product catalog

- [x] Add idempotent, convergent Rails seeds for the three supplied Restaurants and ten supplied Products, keyed by `code` and `sku`; set supplied IDs only when available without overwriting unrelated records, and ensure the PostgreSQL ID sequences remain valid.
- [x] Add focused Minitest coverage proving initial creation and rerun convergence, including `active: true` and `deleted_at: nil` for matching master records.
- [x] Inspect the local development database before mutation; stop if any requested explicit ID belongs to a different record. Preserve unrelated rows and seed only the development database with `bin/rails db:seed`.
- Route: **delegated direct**. Trigger evidence: behavior and focused test require coordinated changes to seed code and tests; project test execution is delegated.
- Acceptance: all supplied field values and safe requested IDs are present; repeated seed runs converge without duplicate keyed records or changing unrelated records; test and development environments remain distinct.
- Checks: strict TDD; focused seeds test RED/GREEN/REFACTOR; full `bin/rails test`; inspect existing development rows before `bin/rails db:seed`, then query back exact rows/IDs.
- Commit evidence: user-owned; do not commit, push, or open a PR.
- Status: complete (uncommitted; user owns commit/PR). RED: focused seeds test failed (1 run, 1 assertion) because seed loading created no catalog rows. GREEN: focused suite passed (2 runs, 17 assertions); full test suite passed (11 runs, 79 assertions). Development database was empty before seeding; `bin/rails db:seed` created the requested 3 restaurants and 10 products in `niufoods_development`; exact readback passed, with ID sequences at 3 and 10. Collision behavior and rerun convergence are covered by the focused test.

### OM-07 — Build the React operational orders dashboard

- [x] Serve a dashboard page at the Rails root with an accessible React mount point and locally built frontend assets; preserve existing Rails/Importmap behavior outside the dashboard.
- [x] Fetch orders and restaurants from the existing same-origin `/api/v1` endpoints and join by `restaurant_id`; show order identifier, destination, total CLP, pickup/delivery type, creation time, and dispatch status. Provide loading, empty, and error states; allow selecting an order to inspect customer and item details when available.
- [x] Add focused frontend tests for required order fields, restaurant-name mapping, status/type labels, empty/loading/error states, and order selection; add Rails integration coverage for the dashboard entry route.
- Route: **delegated direct**. Trigger evidence: implementation spans Rails routing/view and multiple non-trivial React, styling, and test files; reading that prepares the write was delegated to the explorer.
- Acceptance: `GET /` serves the React dashboard, all assignment-required fields are correctly rendered from current APIs, there is no dependency on external runtime CDNs, and the UI remains usable on narrow screens.
- TDD/verification: strict TDD; observe failing frontend and Rails route tests before implementation, then passing checks and refactor evidence. Run focused frontend tests/build and `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test`.
- Commit evidence: user-owned; report changed files and verification, but do not commit.
- Status: implementation and functional checks complete (uncommitted; user owns commit/PR); native review pending. Strict TDD: RED: the new Rails root integration test returned 404 before the dashboard route/controller/view existed; the frontend test command failed because the dashboard component did not exist. GREEN: offline dependency installation completed for cached React 18.3.1, ReactDOM 18.3.1, esbuild 0.28.0; `npm test` passed 3 tests and `bin/rails test test/integration/dashboard_test.rb` passed 1 run / 5 assertions. REFACTOR: guarded browser-only React mounting so the component can be imported for Node rendering tests, externalized React during test bundling to keep the test artifact small, and reran checks: `npm test` passed 3/3; `npm run build` generated the local 143.1 KB dashboard bundle; `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test` passed 21 runs / 118 assertions. No failures/errors/skips. Parent spot-check: `npm test` passed 3/3. `jsdom` was not used because its uncached `cssstyle` dependency prevented offline installation; frontend coverage uses React server rendering for required fields and view states/selection. No network access or commits.

### OM-08 — Apply Spanish localization, Niu branding, and an inert search field

- [x] Translate all dashboard UI, accessibility labels, fallback text, and page metadata into Spanish.
- [x] Add the official Niu Sushi and Niu Foods logos as transparent PNG assets from the official logo sources; use the Niu Sushi site palette (brand red `#ef1010`, charcoal `#232227`/`#29282d`, and white) consistently across the dashboard.
- [x] Add an accessible text search input with a Spanish placeholder, but do not connect it to state, filtering, submission, or any search behavior.
- [x] Update frontend tests for Spanish labels, logos, and the inert input; preserve the existing dashboard behavior and API contract.
- Route: **delegated direct**. Trigger evidence: the change spans React markup, CSS, two brand assets, and frontend tests; required brand/source mapping was delegated before writing.
- Acceptance: no user-facing dashboard text remains in English; both real brand marks display without opaque black backgrounds; colors match the publicly visible Niu Sushi brand tokens; the search field accepts text but does not alter the order list.
- Checks: strict TDD; record RED/GREEN/REFACTOR; run `npm test`, `npm run build`, and `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test`; inspect generated PNG dimensions/transparency and visually read back the dashboard.
- Brand evidence: official logo assets from `https://www.niusushi.cl/assets/images/niusushi/niusushi-logo-header.svg` and `https://www.niusushi.cl/assets/images/desktop/niufoods-logo-footer.svg`; official site exposes brand tokens `--brand-primary: #ef1010`, `--bg-navbar: #232227`, and `--bg-body-order-success: #29282d`.
- Commit evidence: user-owned; report changed files and verification, but do not commit.
- Status: complete (uncommitted; user owns commit/PR). Strict TDD: RED: the new assertions failed against the English dashboard, missing brand marks/search field, and English HTML title. GREEN: official SVGs were copied locally and converted with `rsvg-convert` to transparent RGBA PNGs (Niu Foods 920×380; Niu Sushi 920×353); Spanish UI, metadata, accessibility labels, official palette, and a native text input with no state/handler/filter were implemented. REFACTOR/final checks: `npm test` passed 4 tests; `npm run build` produced the local JS bundle; `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test` passed 21 runs / 120 assertions, zero failures/errors/skips; `git diff --check` passed. Tests inspect PNG alpha transparency, required official palette tokens, Spanish render states/details/fallbacks, and verify the input is editable but has no event/value behavior. No network use, backend/API changes, diagram edits, or commits.

### OM-09 — Refine dashboard logo sizing, dark brand surfaces, and search styling

- [ ] Correct logo sizing and placement so the Niu marks are compact, legible, and do not dominate or distort the dashboard header; retain appropriate aspect ratio and responsive sizing.
- [ ] Apply the official Niu Sushi dark charcoal surfaces with brand-red accents and readable light text so both logos remain visible, using the supplied screenshots as visual guidance.
- [ ] Restyle the inert text search field to fit the dashboard design with clear focus/hover states and responsive layout; do not add search behavior.
- [ ] Add/update frontend assertions for bounded responsive logo sizing and the branded search/control styling while preserving Spanish UI and order behavior.
- Route: **delegated direct**. Trigger evidence: styling/markup and tests span multiple non-trivial frontend files; existing visual symptoms and CSS constraints must be investigated with the write.
- Acceptance: logos render at intentional dashboard scale without cropping or distortion; the overall dashboard uses the official dark Niu Sushi palette and adequate contrast; the search input is visually integrated, accessible, and still behaviorless.
- Checks: strict TDD; record observed RED/GREEN/REFACTOR; run `npm test`, `npm run build`, full Rails tests, and `git diff --check`; visually inspect the served page against the supplied screenshots.
- Commit evidence: user-owned; no commits, push, PR, or diagram edits.
- Status: not started.

## Progress and Evidence

- OM-08 completed Spanish dashboard text/accessibility/title/fallbacks, official Niu Foods and Niu Sushi transparent PNG logos with original SVGs retained locally, official charcoal/red palette, and an accessible text-only search field without search behavior. RED was observed against old markup/title. Final `npm test`: 4 passed; `npm run build`: successful; full Rails suite: 21 runs / 120 assertions, no failures/errors/skips; `git diff --check` passed.
- OM-07 implementation added the React dashboard, same-origin API fetch/join, accessible responsive order cards, optional customer/item detail, local compiled assets, and focused test coverage. `npm test` passed 3 tests; `npm run build` succeeded; full Rails suite passed 21 runs / 118 assertions.
- RDD remains enabled globally. Parent risk assessment classified the diff high/unassessable because the dashboard files are untracked. Selectorless native STATUS then required an `external.select_intended_untracked` input with provider-bound JSON; that operation is unavailable in the current tool surface, so no guessed selection or alternative review command was run. Native review is pending this exact collection input. Parent `npm test` spot-check passed 3/3; `git diff --check` passed.
- OM-07 exploration confirmed the full assignment expects a dashboard with order identifier, destination, total, order type, creation timestamp, and dispatch status. The Rails root currently has no page; orders API exposes `restaurant_id` but not restaurant name, so the dashboard must load `/api/v1/restaurants` and join by ID. The existing order response supports optional customer/item details. React/importmap integration and frontend test tooling are not installed; use a local build rather than runtime CDN dependencies.
- Completed exploration: confirmed Rails 8.1.4/Ruby 4.0.7 skeleton, SQLite configuration, empty application route/domain surface, Minitest/fixtures, and configured `bin/ci` checks.
- OM-01 proposal/spec alignment edits are complete and were read back; verified all three resources use `deleted_at`, Restaurant `active` is independent/editable, deleted records are hidden from GET, history is retained, and route/method scope is unchanged. Documentation-only structural check passed; test/runtime harness N/A.
- Repository status before implementation: branch `core/feature/order-module-init` at the same commit as `main`; pre-existing untracked OpenSpec change files must be preserved.
- Completed implementation/check work awaiting user commit: OM-01 documentation only.
- OM-02 implementation verified against local PostgreSQL 14. `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test`: 5 runs, 22 assertions, 0 failures, 0 errors, 0 skips (including parent spot-check). `bin/rails db:create db:migrate RAILS_ENV=test` succeeded; development migration is up.
- Shell default Ruby was 2.6; Rails checks require selecting project Ruby 4.0.7 on `PATH`.
- OM-04 CSRF continuation complete: enabled controller forgery protection in a request-test context and observed no-token JSON POST return 422 (RED); added controller-local `skip_forgery_protection` only to `Api::V1::OrdersController`, then the no-token JSON create returned 201 (GREEN). Focused OM-04 request/concurrency suite passed 9 runs / 32 assertions; full suite passed 14 runs / 54 assertions (REFACTOR), no failures/errors/skips. `git diff --check` passed. The exemption is justified by the API being stateless and not using cookie/session authentication; web-controller protections and app-wide settings are unchanged.
- OM-04 implementation: `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test`: 13 runs, 52 assertions, 0 failures, 0 errors, 0 skips. Focused request/concurrency suite: 8 runs, 30 assertions, 0 failures, 0 errors, 0 skips. `bin/rails routes` confirms only GET/POST `/api/v1/orders`, GET/DELETE `/api/v1/orders/:id`; no order PUT/PATCH or standalone order-item routes. No manual running-server Postman smoke was performed.
- OM-04 Postman example: `POST http://localhost:3000/api/v1/orders`, header `Content-Type: application/json`, header `Idempotency-Key: postman-order-001`, body `{"order":{"restaurant_id":1,"order_type":"delivery","customer_name":"Ada Lovelace","customer_phone":"+56912345678","delivery_address":"Av. Providencia 123","items":[{"product_id":1,"quantity":2}],"total_clp":1,"price_clp":1}}`. Client totals/prices are ignored; response carries persisted totals and snapshots.
- OM-03 API implementation and request verification are complete; OM-04 APIs and OM-06 catalog seeding are also complete; pending OM-05 full checks/docs. Formal native review could not yet scope the candidate cleanly because unrelated existing diagram modification is in the tracked diff and untracked selection was requested; do not absorb or edit the diagram.
- OM-03 changed files: `config/routes.rb`, `app/controllers/api/v1/restaurants_controller.rb`, `app/controllers/api/v1/products_controller.rb`, `test/integration/api_v1_catalog_test.rb`. `git diff --check` passed; generated log/cache changes from test runs were discarded.
- OM-06 added `db/seeds.rb` and `test/integration/seeds_test.rb`. Focused seeds verification: 2 runs, 17 assertions, 0 failures/errors/skips; full `bin/rails test`: 11 runs, 79 assertions, 0 failures/errors/skips. Development DB inspection before mutation showed no Restaurants or Products; `bin/rails db:seed` targeted `niufoods_development` and completed; exact readback verified supplied IDs, names, codes/SKUs, integer CLP prices, `active=true`, `deleted_at=nil`, and nil Restaurant `dispatch_url`. PostgreSQL sequences read back at 3 (restaurants) and 10 (products); no test seed replant ran.
- OM-10 implemented Sidekiq/Redis dispatch, transaction-safe enqueue placement, simulated-store endpoint, retry/error transitions, local Compose dependencies, and developer setup/run instructions. Strict-TDD RED was observed before source work; focused suite passed 11 runs / 49 assertions, full suite passed 32 runs / 169 assertions, and live Rails + Sidekiq + Redis smoke dispatched an order and confirmed replay did not add work. Exact command outcomes and the connection-pool compatibility pin are recorded in the OM-10 status above. Docker images were not fetched or started; local compose syntax passed. No diagrams changed.
- Commits/PRs: user-owned; none created by assistant.
- Native review: preflight stopped at `intended_untracked_selection_required`; no review transaction was started or consented. Resume only by satisfying that exact provider-issued collection input, then query STATUS again.

## Next Step

OM-09 dashboard visual refinements and OM-05 final backend verification remain separate follow-up tasks. OM-10 is complete on the current branch (`main`); diagrams remain read-only. Do not commit, push, or open a PR; the user handles delivery actions.

## Document Locator

- Repository-relative: `odd/tasks/order-management.md`
- Absolute: `/Users/amaromontero/Software/niufoods-test/niufoods/odd/tasks/order-management.md`
