# Development Roadmap

## Phase 1: Foundation
- Set secrets and device-specific API URL; start PostgreSQL and apply Alembic migration.
- Download/inspect WISDM under its terms; confirm data format, sampling frequency, units, and all required labels.
- Add CI for Python tests, JS lint/type-free syntax checks, dependency audits, and migration checks.

## Phase 2: Model Validation
- Train subject-held-out Random Forest and inspect per-class confusion matrix and class balance.
- Compare model inputs against Expo sensor units and phone placements; assess drift and confidence thresholds.
- Add an approved artifact registration/deployment step and persist model version IDs with predictions.

## Phase 3: Product Hardening
- Add rate limiting, refresh/revocation strategy, secret manager, HTTPS, database backups, observability, and privacy/retention controls.
- Implement per-user timezone boundaries, robust offline sensor buffering, reconnect/sync state, and retry-safe prediction windows.
- Test Android and iOS physical devices, permissions denial, backgrounding, low battery, empty/loading/error states, and accessibility.

## Phase 4: Growth
- Improve activity segmentation and daily rollup rebuild tooling; add user export/deletion workflow.
- Benchmark model adapters and promote XGBoost or a temporal neural model behind the same predictor interface when held-out results justify it.
- Add deployment automation, staged rollout, model monitoring, rollback, and migration compatibility checks.