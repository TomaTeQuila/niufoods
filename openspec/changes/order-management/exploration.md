## Exploration: Order management

### Current State
The repository contains a Rails 8.1 skeleton, not an implemented order workflow. `config/routes.rb` exposes only the health route; there are no order, item, product, or dispatch models, migrations, controllers, jobs, or feature tests. `config/database.yml` and `Gemfile` still use SQLite and the default Rails stack. `README.md` describes a planned PostgreSQL-backed API, server-calculated totals, historical item-price snapshots, `Idempotency-Key`, asynchronous dispatch to a simulated store, and an order dashboard; those are intentions, not current behavior. The README's statement that Rails has not been initialized is stale relative to the checked-in application skeleton.

### Affected Areas
- `config/routes.rb` — planned order and simulated-store endpoints require routes.
- `app/models/` and `db/` — order, item, product, idempotency, and dispatch persistence do not exist.
- `app/controllers/` — request validation and order read/write APIs do not exist.
- `app/jobs/` — asynchronous store dispatch and retry behavior do not exist.
- `test/models/`, `test/integration/`, and `test/jobs/` — behavior needs new Minitest coverage under strict TDD.
- `Gemfile` and `config/database.yml` — the documented PostgreSQL/Redis/Sidekiq target differs from the current SQLite/Solid Queue skeleton.
- `app/javascript/` — the planned React dashboard differs from the current Importmap/Stimulus setup.

### Approaches
1. **Vertical Rails order slice** — specify and build order creation/query, transactional item-price snapshots, and idempotency before dispatch and dashboard.
   - Pros: Delivers a testable business invariant first; keeps failure cases and API contract explicit; can defer infrastructure changes until needed.
   - Cons: Dispatch and dashboard are not part of the first slice; temporary use of current infrastructure may diverge from the documented target.
   - Effort: Medium.

2. **Infrastructure-first full target stack** — adopt PostgreSQL, Redis, Sidekiq, and React before implementing order behavior.
   - Pros: Aligns runtime dependencies with the documented architecture early.
   - Cons: Broad setup and integration work precedes validation of the order contract; increases simultaneous failure modes and testing cost.
   - Effort: High.

### Recommendation
Start with a vertical Rails order slice and define the API payload, money representation, idempotency scope/response semantics, and order-versus-dispatch status transitions in the proposal/spec. Keep PostgreSQL/Sidekiq/React as explicit later slices unless the intended acceptance scope requires them immediately. Follow the configured RED → GREEN → REFACTOR workflow with `bin/rails test`; use `bin/ci` for full verification.

### Risks
- The documented target stack and checked-in skeleton disagree; planning must distinguish required acceptance criteria from aspirational architecture.
- A duplicate idempotency key with a different payload, concurrent requests, and dispatch failures need explicit semantics before implementation.
- The meaning of “order management” is not yet bounded: creation/query alone versus dispatch/dashboard could materially change scope.
- Native `sdd-status` resolves this workspace as `openspec`, while the session selected `hybrid`; the Engram mirror does not establish a native hybrid locator or change readiness.

### Ready for Proposal
Yes, for a scoped proposal that records the open product decisions above. The orchestrator should confirm the intended acceptance boundary before committing to dispatch/dashboard work and reconcile the selected hybrid persistence expectation with native OpenSpec resolution before routing dependent phases.
