# Docker reviewer setup

## Objective
Let reviewers start Niufoods with Docker Compose, load the seeded catalog, inspect the dashboard, submit sample orders, and verify asynchronous dispatch without changing application/domain logic.

## Problem and why
Compose currently provides only Postgres and Redis, while the README requires host Ruby, environment exports, and separate web/Sidekiq terminals. A concise containerized happy path reduces reviewer setup friction.

## Scope and constraints
- Authorized files: `docker-compose.yml`, `README.md`, and this feature document.
- No Rails application, API, domain, job, model, service, or React logic changes.
- Preserve the existing production Dockerfile unless Compose proves a container setup change is necessary.
- No remote image pulls/builds or Compose runtime commands; Docker Hub authorization was not granted.
- README language remains Spanish and leads with the reviewer happy path.
- Keep the feature under the advisory ~400 authored changed-line heuristic.

## TDD and checks
- Strict TDD: enabled; source: project instructions.
- Exact runner: `PATH="$HOME/.rbenv/versions/4.0.7/bin:$PATH" bin/rails test`.
- Validation: `docker compose config --quiet`; exact Rails test runner above; `git diff --check`.
- Do not run `docker compose build/up` or pull images; Docker runtime smoke checks are intentionally skipped because remote Docker Hub access was not authorized.

## Route and forecast
- Route: delegated direct, because implementation spans Compose and README and the Docker/config/README mapping was performed as preparation by the delegated writer.
- Forecast: approximately 229 authored changed lines across Compose, README, and this task document (183 additions/deletions in source files plus 46 task-document lines); below ~400 lines.

## Tasks
- [x] DRS-1: Added web and Sidekiq Compose services and replaced README setup with reviewer-oriented Spanish quick path, seed, simulator, API/Postman/idempotency, verification, and cleanup instructions.
- [x] DRS-2: Replaced voseo with neutral Latin American Spanish forms throughout the README; preserved commands, API examples, and technical meaning.

## Progress
- [x] Read-only exploration confirmed existing Docker, database, worker, simulator, seed, and dashboard behavior.
- [x] Created and read back this task document before source edits.
- [x] Implemented DRS-1 without changing app/domain/core logic.
- [x] `docker compose config --quiet` passed.
- [x] `git diff --check` passed.
- [x] Ran the exact Rails suite; it exited 1: 33 tests, 149 assertions, 3 failures, 1 error. The observed failures include a duplicate restaurant ID 1 during the seed test, a model association expecting 1 but seeing 4, and catalog API tests seeing seeded restaurants/products alongside test records.
- [x] Skipped Docker image build/runtime checks; no Docker Hub pull authorization was granted.
- [x] Updated and read back this task document and its Engram mirror.
- [x] Work-unit commit `3f3dd46` (`chore(docker): add reviewer compose setup`) on `chore/docker-reviewer-setup`; no push or PR.
- [x] DRS-2 language correction passed README readback for voseo forms and `git diff --check`.
- [x] DRS-2 work-unit commit `866d880` (`docs(readme): neutralize Spanish instructions`).

## Acceptance criteria
- `docker compose up --build` describes a web/dashboard service and Sidekiq worker backed by Compose Postgres/Redis, with internal dispatch using Compose DNS.
- Reviewers can seed the exact catalog IDs used by the existing simulator.
- README covers the quick path, dashboard URL, logs, simulator command, GET orders check, Postman POST with exact idempotency header/payload and expected 201/200 behavior, teardown, data reset, and test command.
- No app/domain/core logic files are changed.
- All authorized checks are recorded with observed results; Compose runtime is clearly marked skipped.
