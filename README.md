# BFit

BFit is an Expo React Native application with a FastAPI/PostgreSQL backend for tracking steps and recognizing Walking, Running, Sitting, and Standing. The first model adapter is Random Forest, trained on WISDM smartphone accelerometer data; its interface keeps future model families independent of API and app contracts.

## Project Layout

- `mobile/` - React Native app in JavaScript, React Navigation, React Query, Zustand, Axios, Expo sensors, charts, and secure token storage.
- `backend/` - FastAPI, SQLAlchemy, Pydantic, JWT authentication, repositories, services, and Alembic migrations.
- `ml/` - WISDM preprocessing, subject-held-out training/evaluation, model artifact and metrics output.
- `docs/` - architecture, data model, API contract, and roadmap.

## Local Setup

1. Install Python 3.11+, Node.js LTS, npm, and Docker Desktop.
2. Start PostgreSQL: `docker compose up -d db`.
3. Copy `.env.example` to `.env` and `backend/.env`; set a unique random `SECRET_KEY` in `backend/.env` before using real accounts. The supplied local `.env` files are ignored by git.
4. Install backend packages with `python -m pip install -r backend/requirements.txt`.
5. Run migrations: `cd backend && alembic upgrade head`.
6. Start the API: `cd backend && uvicorn app.main:app --reload`.
7. In `mobile/.env`, set `EXPO_PUBLIC_API_URL` to the API address reachable from the target. Android emulator: `http://10.0.2.2:8000/api/v1`; iOS simulator or web: `http://localhost:8000/api/v1`; physical device: use the development PC's current Wi-Fi IPv4 address. If that address changes, update `.env` and restart Metro with `cd mobile && npm run start:lan`.
8. Start Expo with `cd mobile && npm start` and open the app in Expo Go or a development build. Scan the newly printed QR code after changing the API URL; an already-open Expo Go session may keep its previous bundle.

For production, configure `EXPO_PUBLIC_API_URL` as a public HTTPS API endpoint in the build environment. A phone cannot reach `localhost`, an Android emulator host, or the developer PC's private LAN address in a production install. Rebuild the native app after adding or changing native Expo modules.

Interactive API docs are at `/docs`, OpenAPI JSON at `/openapi.json`, and health check at `/health`.

## Product Behavior

- Daily step goals start at 6,000 until at least three positive step-history days exist in the last week. Then BFit suggests 110% of the average, rounded to the nearest 500 and clamped between 3,000 and 12,000. The suggestion is optional and editable in Goals.
- Distance and calories are rough walking estimates from steps, height, and weight. They are not medical or clinical measurements.
- Motivational quotes rotate on app launch and foreground return. Daily movement reminders are optional local notifications; they require user permission and a native mobile runtime.
- For phone testing, use `npm run start:lan`, point `EXPO_PUBLIC_API_URL` to this PC's current Wi-Fi IPv4, and reload using the newly printed Expo QR code after changing that address. Production builds must use a deployed HTTPS API URL.

Run the mobile logic tests with `cd mobile && npm test`. Run backend tests with `cd backend && python -m pytest tests -q` after activating the backend environment.

## Train the Version 1 Model

Download WISDM from its official source and follow its license/terms. Keep raw data outside git; the WISDM Accelerometer dataset includes Walking, Jogging, Sitting, and Standing among its labels. The training pipeline maps Jogging to the product label Running. It requires a labeled sample for each target class and fails instead of silently producing a partial classifier.

```bash
python -m pip install -r backend/requirements.txt
python ml/training/train_random_forest.py /path/to/WISDM_ar_v1.1_raw.txt
```

The trainer uses 200-sample windows at 20 Hz with 50% overlap, grouped subject-held-out evaluation, and writes `ml/artifacts/random_forest.joblib` and `ml/artifacts/metrics.json`. Register the evaluated artifact and metrics in PostgreSQL by running `cd backend && python -m app.ml.register_model` after migration. Configure `ML_ARTIFACT_PATH` so the API process can read the artifact. No model artifact or dataset is committed. Until trained/installed, `/activity/predict` correctly returns HTTP 503 and the mobile dashboard says classification is not ready.

## DeepConvLSTM Candidate

DeepConvLSTM is the current selected model when its trained checkpoint exists. It was evaluated on the same provided split as Random Forest:

| Model | Accuracy | Weighted F1 | Macro F1 |
|---|---:|---:|---:|
| Random Forest 1.0.0 | 92.5% | 0.922 | 0.855 |
| DeepConvLSTM 2.0.0 | 95.7% | 0.956 | 0.911 |

The improvement is on this dataset's provided train/test split, not a guarantee of real-phone accuracy. Train it from the repository root to reproduce the candidate:

```bash
backend/.venv/Scripts/python.exe -m ml.training.train_deepconv_lstm ml/data/kagglebfit
```

It writes `ml/artifacts/deepconv_lstm.pt` and `ml/artifacts/deepconv_lstm_metrics.json`. With `ACTIVITY_MODEL=auto` (default), the API uses this checkpoint when present and otherwise falls back to Random Forest. Register its metadata in PostgreSQL with model name `deepconv_lstm` and version `2.0.0`. Set `ACTIVITY_MODEL=random_forest` to roll back.

## Production Readiness Notes

This repository is the first working product scaffold, not a deployed or security-certified service. Before release, configure HTTPS, managed PostgreSQL/backups, secret management, rate limits and abuse monitoring, structured logs/metrics, token lifecycle/revocation, privacy/retention policy, crash reporting, and device/participant validation. Verify WISDM and app sensor units and phone placement end-to-end; step data is sourced from the native pedometer and is not inferred by the classifier. Evaluation metrics are saved with the model artifact; registering deployments in `model_versions` should be part of the release pipeline.

See [System Architecture](docs/architecture.md), [Database Design](docs/database.md), [API Contract](docs/api.md), and [Roadmap](docs/roadmap.md).